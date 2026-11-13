//
//  CoreDataManageable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

protocol CoreDataManageable {
    var context: NSManagedObjectContext { get }
    
    func saveContext() throws
    func fetch<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>) throws -> [Entity]
    func delete(_ object: NSManagedObject)
    @MainActor var frameDataGeneration: Int { get }
    @MainActor func replaceFrameData(characters: [Character], moves: [Move]) throws
}

extension CoreDataManageable {
    @MainActor var frameDataGeneration: Int { 0 }

    @MainActor
    func replaceFrameData(characters: [Character], moves: [Move]) throws {
        try saveFrameDataSnapshot(characters: characters, moves: moves)
    }

    @MainActor
    func saveFrameDataSnapshot(characters: [Character], moves: [Move]) throws {
        let staging = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        staging.persistentStoreCoordinator = context.persistentStoreCoordinator

        let oldMoves = try staging.fetch(MoveEntity.fetchRequest())
        let oldCharacters = try staging.fetch(CharacterEntity.fetchRequest())
        oldMoves.forEach(staging.delete)
        oldCharacters.forEach(staging.delete)

        let newCharacters = characters.map { CharacterDTO(domain: $0).toEntity(in: staging) }
        let newMoves = moves.map { MoveDTO(domain: $0).toEntity(context: staging) }
        try staging.save()

        let changes: [AnyHashable: Any] = [
            NSDeletedObjectsKey: oldMoves.map(\.objectID) + oldCharacters.map(\.objectID),
            NSInsertedObjectsKey: newCharacters.map(\.objectID) + newMoves.map(\.objectID),
        ]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
    }
}
