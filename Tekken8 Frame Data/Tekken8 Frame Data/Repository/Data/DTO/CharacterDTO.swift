//
//  CharacterDTO.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

struct CharacterDTO {
    let id: Int64
    let name: String
    let imageURL: String
    
    init(entity: CharacterEntity) {
        id = entity.id
        name = entity.name ?? "알 수 없음"
        imageURL = entity.imageURL ?? ""
    }
    
    init(domain: Character) {
        id = domain.id
        name = domain.name
        imageURL = domain.imageURL
    }
    
    func toDomain() -> Character {
        Character(id: id, name: name, imageURL: imageURL)
    }
    
    @discardableResult
    func toEntity(in context: NSManagedObjectContext) -> CharacterEntity {
        let entity = CharacterEntity(context: context)
        entity.id = Int64(id)
        entity.name = name
        entity.imageURL = imageURL
        return entity
    }
}
