import Foundation

final class MemoComposeViewModel {
    enum SaveResult: Equatable {
        case skipped
        case persisted
        case failed
    }

    private let memoViewModel: MemoViewModel
    private let analytics: AnalyticsClient
    private(set) var memo: Memo?
    private(set) var isEditing: Bool
    var characterName: String
    var isPinned: Bool

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
        let result = save(title: title, body: body)
        if result != .failed, memo != nil {
            isEditing = false
        }
        return result
    }

    func save(title: String, body: String) -> SaveResult {
        let mode: TK8AnalyticsMemoMode = memo == nil ? .create : .edit
        // Reuse the original stored string when only metadata changes.
        let storedBody = memo.flatMap { $0.title == title && $0.rawBody == body ? $0.body : nil }
            ?? (title + "\n" + body)
        switch memoSaveDecision(
            memo: memo,
            selectedCharacterName: characterName,
            title: title,
            body: storedBody,
            isPinned: isPinned
        ) {
        case .emptyContent:
            analytics.log(.memoSaveSkipped(mode: mode, reason: .emptyContent))
            return .skipped
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
    guard !trimmedTitle.isEmpty || !trimmedBody.isEmpty else {
        return .emptyContent
    }
    guard let memo else { return .create }

    let selectedCharacter = selectedCharacterName ?? "common"
    guard memo.characterName != selectedCharacter ||
            memo.title != title ||
            memo.body != body ||
            memo.isPinned != isPinned else {
        return .unchanged
    }
    return .update
}
