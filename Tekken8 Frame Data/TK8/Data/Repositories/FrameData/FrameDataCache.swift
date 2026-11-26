import CoreData

final class FrameDataCache {
    enum ResponseFreshness {
        case current
        case superseded
    }

    private let coreData: CoreDataManageable

    init(coreData: CoreDataManageable) {
        self.coreData = coreData
    }

    @MainActor var generation: Int { coreData.frameDataGeneration }

    @MainActor
    func fetchCharacters() throws -> [CharacterDTO] {
        try coreData.fetch(CharacterEntity.fetchRequest()).map(CharacterDTO.init(entity:))
    }

    @MainActor
    func reconcileCharacterResponse(_ characters: [CharacterDTO], requestGeneration generation: Int) throws -> ResponseFreshness {
        try reconcileResponse(requestGeneration: generation) {
            let request = CharacterEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", characters.map(\.id))
            let existing = try coreData.fetch(request)
            var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            try save(restoring: existing) {
                var inserted: [CharacterEntity] = []
                for character in characters {
                    if let entity = byID[character.id] {
                        character.update(entity)
                    } else {
                        let entity = character.toEntity(in: coreData.context)
                        inserted.append(entity)
                        byID[character.id] = entity
                    }
                }
                return inserted
            }
        }
    }

    @MainActor
    func fetchMoves(characterName name: String) throws -> [MoveDTO] {
        let request = MoveEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: true)]
        request.predicate = NSPredicate(format: "characterName == %@", name)
        return try coreData.fetch(request).map(MoveDTO.init(entity:))
    }

    @MainActor
    func reconcileMoveResponse(_ moves: [MoveDTO], requestGeneration generation: Int) throws -> ResponseFreshness {
        try reconcileResponse(requestGeneration: generation) {
            let request = MoveEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", moves.map(\.id))
            let existing = try coreData.fetch(request)
            var byID = Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

            try save(restoring: existing) {
                var inserted: [MoveEntity] = []
                for move in moves {
                    if let entity = byID[move.id] {
                        move.update(entity)
                    } else {
                        let entity = move.toEntity(context: coreData.context)
                        inserted.append(entity)
                        byID[move.id] = entity
                    }
                }
                return inserted
            }
        }
    }

    @MainActor
    private func reconcileResponse(requestGeneration generation: Int, write: () throws -> Void) throws -> ResponseFreshness {
        guard generation == self.generation else { return .superseded }
        try Task.checkCancellation()
        if !coreData.isReplacingFrameData {
            try write()
        }
        return .current
    }

    @MainActor
    private func save<Entity: NSManagedObject>(restoring existing: [Entity], write: () -> [Entity]) throws {
        let originalValues = existing.map { entity in
            let keys = Array(entity.entity.attributesByName.keys)
            return (entity, entity.dictionaryWithValues(forKeys: keys))
        }
        let inserted = write()
        do {
            try coreData.saveContext()
        } catch {
            inserted.forEach(coreData.delete)
            for (entity, original) in originalValues {
                entity.setValuesForKeys(original)
            }
            throw error
        }
    }
}
