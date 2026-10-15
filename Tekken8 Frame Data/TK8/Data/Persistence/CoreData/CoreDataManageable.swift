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
    func deleteAll() throws
}
