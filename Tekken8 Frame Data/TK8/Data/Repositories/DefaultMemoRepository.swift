//
//  MemoRepository.swift
//  TK8
//

import CoreData

protocol MemoRepository {
    // CRUD
    @discardableResult
    func save(character: String, title: String, body: String, isPinned: Bool) throws -> Memo
    func fetchMemos() throws -> [Memo]
    func update(memo: Memo) throws -> Bool
    func delete(memo: Memo) throws
    func upsert(memos: [Memo]) throws -> MemoImportResult
}

final class DefaultMemoRepository: MemoRepository {
    private let coreDataManager: CoreDataManageable

    init(coreDataManager: CoreDataManageable) {
        self.coreDataManager = coreDataManager
    }

    @discardableResult
    func save(character: String, title: String, body: String, isPinned: Bool) throws -> Memo {
        let context = coreDataManager.context
        let entity = MemoEntity(context: context)
        entity.id = UUID()
        entity.characterNameEN = character
        entity.title = title
        entity.body = body
        entity.isPinned = isPinned
        entity.updatedAt = Date()
        do {
            try coreDataManager.saveContext()
        } catch {
            context.delete(entity)
            throw error
        }
        return makeMemo(from: entity)
    }

    func upsert(memos: [Memo]) throws -> MemoImportResult {
        var insertedCount = 0
        var updatedCount = 0
        var skippedCount = 0

        for memo in memos {
            if let entity = try fetchMemoEntity(id: memo.id) {
                guard shouldUpdate(entity: entity, with: memo) else {
                    skippedCount += 1
                    continue
                }
                apply(memo, to: entity, preserveUpdatedAt: true)
                updatedCount += 1
            } else {
                let entity = MemoEntity(context: coreDataManager.context)
                apply(memo, to: entity, preserveUpdatedAt: true)
                insertedCount += 1
            }
        }

        try coreDataManager.saveContext()
        return MemoImportResult(
            insertedCount: insertedCount,
            updatedCount: updatedCount,
            skippedCount: skippedCount
        )
    }
    
    func fetchMemos() throws -> [Memo] {
        let request = MemoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let result = try coreDataManager.fetch(request)
        return result.map(makeMemo(from:))
    }

    private func makeMemo(from entity: MemoEntity) -> Memo {
        Memo(
            id: entity.id ?? UUID(),
            characterName: entity.characterNameEN ?? "none",
            title: entity.title ?? "",
            body: entity.body ?? "",
            isPinned: entity.isPinned,
            updatedAt: entity.updatedAt ?? Date()
        )
    }

    func update(memo: Memo) throws -> Bool {
        guard let entity = try fetchMemoEntity(id: memo.id) else { return false }

        // Pin만 바뀐경우 Date를 갱신하면 안됨
        if isPinOnlyChanged(from: entity, to: memo) {
            entity.isPinned = memo.isPinned
        } else {
            entity.characterNameEN = memo.characterName
            entity.title = memo.title
            entity.body = memo.body
            entity.isPinned = memo.isPinned
            entity.updatedAt = Date()
        }
        do {
            try coreDataManager.saveContext()
        } catch {
            coreDataManager.context.refresh(entity, mergeChanges: false)
            throw error
        }
        return true
    }
    
    func delete(memo: Memo) throws {
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", memo.id as CVarArg)
        guard let willDeleteMemo = try coreDataManager.fetch(request).first else { return }
        coreDataManager.delete(willDeleteMemo)
        try coreDataManager.saveContext()
    }

    private func isPinOnlyChanged(from entity: MemoEntity, to memo: Memo) -> Bool {
        return entity.characterNameEN == memo.characterName &&
            memo.hasSameContent(title: entity.title, body: entity.body) &&
            entity.isPinned != memo.isPinned
    }

    private func fetchMemoEntity(id: UUID) throws -> MemoEntity? {
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try coreDataManager.fetch(request).first
    }

    private func shouldUpdate(entity: MemoEntity, with memo: Memo) -> Bool {
        let updatedAt = entity.updatedAt ?? .distantPast
        return memo.updatedAt > updatedAt
    }

    private func apply(_ memo: Memo, to entity: MemoEntity, preserveUpdatedAt: Bool) {
        entity.id = memo.id
        entity.characterNameEN = memo.characterName
        entity.title = memo.title
        entity.body = memo.body
        entity.isPinned = memo.isPinned
        entity.updatedAt = preserveUpdatedAt ? memo.updatedAt : Date()
    }
}
