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

    func save(character: String, title: String, body: String) throws {
        if let error = saveError { throw error }
        memos.append(Memo(id: UUID(), characterName: character, title: title, body: body, updatedAt: Date()))
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
}
