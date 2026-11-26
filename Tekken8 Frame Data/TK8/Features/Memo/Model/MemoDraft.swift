import Foundation

struct MemoDraft: Identifiable {
    let id: UUID
    let memo: Memo?
    let title: String
    let rawBody: String
    let characterName: String
    let isPinned: Bool
}

@MainActor
final class MemoDraftStore {
    private(set) var drafts: [MemoDraft] = []

    func retain(_ draft: MemoDraft) {
        remove(id: draft.id)
        drafts.insert(draft, at: 0)
    }

    func remove(id: UUID) {
        drafts.removeAll { $0.id == id }
    }
}
