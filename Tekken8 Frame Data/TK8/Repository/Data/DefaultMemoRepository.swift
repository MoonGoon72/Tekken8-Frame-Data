//
//  MemoRepository.swift
//  TK8
//

import CoreData

protocol MemoRepository {
    // CRUD
    func save(character: String, title: String, body: String, isPinned: Bool) throws
    func fetchMemos() throws -> [Memo]
    func update(memo: Memo) throws
    func delete(memo: Memo) throws
}

final class DefaultMemoRepository: MemoRepository {
    private let coreDataManager: CoreDataManageable

    init(coreDataManager: CoreDataManageable) {
        self.coreDataManager = coreDataManager
    }

    func save(character: String, title: String, body: String, isPinned: Bool) throws {
        let context = coreDataManager.context
        let entity = MemoEntity(context: context)
        entity.id = UUID()
        entity.characterNameEN = character
        entity.title = title
        entity.body = body
        entity.isPinned = isPinned
        entity.updatedAt = Date()
        try coreDataManager.saveContext()
    }
    
    func fetchMemos() throws -> [Memo] {
        let request = MemoEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        let result = try coreDataManager.fetch(request)
        return result.map {
            Memo(
                id: $0.id ?? UUID(),
                characterName: $0.characterNameEN ?? "none",
                title: $0.title ?? "",
                body: $0.body ?? "",
                isPinned: $0.isPinned,
                updatedAt: $0.updatedAt ?? Date()
            )
        }
    }
    
    func update(memo: Memo) throws {
        let request = MemoEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", memo.id as CVarArg)
        let prevMemo = try coreDataManager.fetch(request)
        guard let entity = prevMemo.first else { return }

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
        try coreDataManager.saveContext()
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
            entity.title == memo.title &&
            entity.body == memo.body &&
            entity.isPinned != memo.isPinned
    }
}
