//
//  CharacterDTO.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

struct CharacterDTO {
    let id: Int64
    let nameEN: String
    let nameKR: String
    let imageURL: String
    
    init(entity: CharacterEntity) {
        id = entity.id
        nameEN = entity.nameEN ?? "알 수 없음"
        nameKR = entity.nameKR ?? "알 수 없음"
        imageURL = entity.imageURL ?? ""
    }
    
    init(domain: Character) {
        id = domain.id
        nameEN = domain.nameEN
        nameKR = domain.nameKR
        imageURL = domain.imageURL
    }
    
    func toDomain() -> Character {
        Character(id: id, nameEN: nameEN, nameKR: nameKR, imageURL: imageURL)
    }
    
    @discardableResult
    func toEntity(in context: NSManagedObjectContext) -> CharacterEntity {
        let entity = CharacterEntity(context: context)
        entity.id = Int64(id)
        entity.nameEN = nameEN
        entity.nameKR = nameKR
        entity.imageURL = imageURL
        return entity
    }
}
