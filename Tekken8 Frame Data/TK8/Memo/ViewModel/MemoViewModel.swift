//
//  MemoViewModel.swift
//  TK8
//

import Combine
import Foundation

final class MemoViewModel: ObservableObject {
    @Published private(set) var memos: [Memo] = []
    @Published private(set) var filteredMemos: [Memo] = []
    private let memoRepository: MemoRepository

    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }

    func fetch() throws {
        memos = try memoRepository.fetchMemos()
    }

    func create(character: String, title: String, body: String) throws {
        try performAndFetch {
            try memoRepository.save(character: character, title: title, body: body)
        }
    }

    func update(memo: Memo) throws {
        try performAndFetch {
            try memoRepository.update(memo: memo)
        }
    }

    func delete(memos: [Memo]) throws {
        try performAndFetch {
            try memos.forEach { try memoRepository.delete(memo: $0) }
        }
    }

    private func performAndFetch(_ action: () throws -> Void) throws {
        try action()
        try fetch()
    }
}
