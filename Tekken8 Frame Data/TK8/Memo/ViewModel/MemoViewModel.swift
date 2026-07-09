//
//  MemoViewModel.swift
//  TK8
//

import Combine
import Foundation

final class MemoViewModel: ObservableObject {
    @Published private(set) var filteredMemos: [Memo] = []
    private(set) var memos: [Memo] = []
    private let memoRepository: MemoRepository
    private let memoBackupCodec: MemoBackupCodec

    init(memoRepository: MemoRepository, memoBackupCodec: MemoBackupCodec = MemoBackupCodec()) {
        self.memoRepository = memoRepository
        self.memoBackupCodec = memoBackupCodec
    }

    // MARK: CRUD methods

    func fetch() throws {
        memos = try memoRepository.fetchMemos()
        filteredMemos = memos
    }

    func create(character: String, title: String, body: String, isPinned: Bool) throws {
        try performAndFetch {
            try memoRepository.save(character: character, title: title, body: body, isPinned: isPinned)
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

    func exportMemos() throws -> MemoBackupExport {
        let exportedAt = Date()
        let memos = try memoRepository.fetchMemos()
        let data = try memoBackupCodec.encode(memos: memos, exportedAt: exportedAt)
        return MemoBackupExport(
            data: data,
            fileName: MemoBackupDocument.fileName(exportedAt: exportedAt)
        )
    }

    func importMemos(from data: Data) throws -> MemoImportResult {
        let memos = try memoBackupCodec.decodeMemos(from: data)
        let result = try memoRepository.upsert(memos: memos)
        try fetch()
        return result
    }

    // MARK: Filter method

    func filter(by keyword: String) {
        if keyword.isEmpty {
            filteredMemos = memos
        } else {
            filteredMemos = memos.filter {
                $0.title.contains(keyword) || $0.body.contains(keyword)
            }.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func resetFilter() {
        filteredMemos = memos
    }

    // MARK: Private methods

    private func performAndFetch(_ action: () throws -> Void) throws {
        try action()
        try fetch()
    }
}
