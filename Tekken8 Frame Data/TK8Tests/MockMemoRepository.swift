//
//  MockMemoRepository.swift
//  TK8Tests
//

@testable import TK8
import Foundation

final class MockMemoRepository: MemoRepository {
    var memos: [Memo] = []
    var saveError: Error?
    var fetchError: Error?

    func save(character: String, title: String, body: String, isPinned: Bool) throws {
        if let error = saveError { throw error }
        memos.append(Memo(id: UUID(), characterName: character, title: title, body: body, isPinned: isPinned, updatedAt: Date()))
    }

    func fetchMemos() throws -> [Memo] {
        if let error = fetchError { throw error }
        return memos
    }

    func update(memo: Memo) throws {
        guard let index = memos.firstIndex(where: { $0.id == memo.id }) else { return }
        memos[index] = memo
    }

    func delete(memo: Memo) {
        memos.removeAll { $0.id == memo.id }
    }

    func upsert(memos: [Memo]) throws -> MemoImportResult {
        var insertedCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for memo in memos {
            guard let index = self.memos.firstIndex(where: { $0.id == memo.id }) else {
                self.memos.append(memo)
                insertedCount += 1
                continue
            }
            guard memo.updatedAt > self.memos[index].updatedAt else {
                skippedCount += 1
                continue
            }
            self.memos[index] = memo
            updatedCount += 1
        }

        return MemoImportResult(
            insertedCount: insertedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount
        )
    }
}
