import Foundation

final class MemoComposeViewModel {
    enum SaveResult: Equatable {
        case empty
        case skipped
        case persisted
        case failed
    }

    private let memoViewModel: MemoViewModel
    private let analytics: AnalyticsClient
    private(set) var memo: Memo?
    private(set) var isEditing: Bool
    var characterName: String
    private(set) var isPinned: Bool

    init(memoViewModel: MemoViewModel, memo: Memo?, analytics: AnalyticsClient) {
        self.memoViewModel = memoViewModel
        self.analytics = analytics
        self.memo = memo
        isEditing = memo == nil
        characterName = memo?.characterName ?? "common"
        isPinned = memo?.isPinned ?? false
    }

    func beginEditing() {
        isEditing = true
        analytics.log(.memoComposeStarted(mode: memo == nil ? .create : .edit))
    }

    func finishEditing(title: String, body: String) -> SaveResult {
        let result = persist(title: title, body: body, isLeavingEditor: false)
        if result == .persisted || result == .skipped {
            isEditing = false
        }
        return result
    }

    func save(title: String, body: String) -> SaveResult {
        persist(title: title, body: body, isLeavingEditor: true)
    }

    func togglePin(title: String, body: String) -> Bool {
        isPinned.toggle()
        if !isEditing, persist(title: title, body: body, isLeavingEditor: false) == .failed {
            isPinned.toggle()
            return false
        }
        return true
    }

    private func persist(title: String, body: String, isLeavingEditor: Bool) -> SaveResult {
        let mode: TK8AnalyticsMemoMode = memo == nil ? .create : .edit
        // Reuse the original stored string when only metadata changes.
        let storedBody: String
        if let memo, memo.title.utf8.elementsEqual(title.utf8), memo.rawBody.utf8.elementsEqual(body.utf8) {
            storedBody = memo.body
        } else {
            storedBody = title + "\n" + body
        }
        switch memoSaveDecision(
            memo: memo,
            selectedCharacterName: characterName,
            title: title,
            body: storedBody,
            isPinned: isPinned
        ) {
        case .emptyContent:
            if isLeavingEditor {
                analytics.log(.memoSaveSkipped(mode: mode, reason: .emptyContent))
            }
            return .empty
        case .unchanged:
            analytics.log(.memoSaveSkipped(mode: mode, reason: .noChanges))
            return .skipped
        case .create, .update:
            var persistedMemo: Memo?
            do {
                if var updated = memo {
                    updated.characterName = characterName
                    updated.title = title
                    updated.body = storedBody
                    updated.isPinned = isPinned
                    try memoViewModel.update(memo: updated) { persistedMemo = updated }
                } else {
                    try memoViewModel.create(character: characterName, title: title, body: storedBody, isPinned: isPinned) {
                        persistedMemo = $0
                    }
                }
            } catch {
                // A refresh failure can follow a successful write.
            }
            guard let persistedMemo else {
                analytics.log(.memoSaveFailed(mode: mode, failureCode: .repositoryError))
                return .failed
            }
            memo = persistedMemo
            analytics.log(.memoSaveSucceeded(mode: mode))
            return .persisted
        }
    }

    func delete() throws {
        if let memo {
            try memoViewModel.delete(memos: [memo])
        }
    }
}

enum MemoSaveDecision: Equatable {
    case emptyContent
    case create
    case unchanged
    case update
}

func memoSaveDecision(
    memo: Memo?,
    selectedCharacterName: String?,
    title: String,
    body: String,
    isPinned: Bool
) -> MemoSaveDecision {
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
    let preservesStoredContent = memo.map { $0.hasSameContent(title: title, body: body) } ?? false
    guard preservesStoredContent || !trimmedTitle.isEmpty || !trimmedBody.isEmpty else {
        return .emptyContent
    }
    guard let memo else { return .create }

    let selectedCharacter = selectedCharacterName ?? "common"
    guard memo.characterName != selectedCharacter ||
            !preservesStoredContent ||
            memo.isPinned != isPinned else {
        return .unchanged
    }
    return .update
}
