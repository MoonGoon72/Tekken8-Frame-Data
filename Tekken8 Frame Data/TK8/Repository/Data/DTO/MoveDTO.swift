//
//  MoveDTO.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

struct MoveDTO {
    let id: Int64
    let sortOrder: Double
    let characterName: String
    let section: String
    let skillNameEN: String
    let skillNameKR: String?
    let skillNickname: String?
    let command: String?
    let judgment: String?
    let damage: String?
    let startupFrame: String?
    let guardFrame: String?
    let hitFrame: String?
    let counterFrame: String?
    let attribute: String?
    let description: String?
    
    init(entity: MoveEntity) {
        id = entity.id
        sortOrder = Double(entity.sortOrder)
        characterName = entity.characterName ?? "알 수 없음"
        section = entity.section ?? "알 수 없는 섹션"
        skillNameEN = entity.skillNameEN ?? "알 수 없는 기술 명"
        skillNameKR = entity.skillNameKR
        skillNickname = entity.skillNickname
        command = entity.command
        judgment = entity.judgment
        damage = entity.damage
        startupFrame = entity.startupFrame
        guardFrame = entity.guardFrame
        hitFrame = entity.hitFrame
        counterFrame = entity.counterFrame
        attribute = entity.attribute ?? ""
        description = entity.descriptions
    }
    
    init(domain: Move) {
        id = Int64(domain.id)
        sortOrder = domain.sortOrder
        characterName = domain.characterName
        section = domain.section
        skillNameEN = domain.skillNameEN ?? ""
        skillNameKR = domain.skillNameKR
        skillNickname = domain.skillNickname
        command = domain.command
        judgment = domain.judgment
        damage = domain.damage
        startupFrame = domain.startupFrame
        guardFrame = domain.guardFrame
        hitFrame = domain.hitFrame
        counterFrame = domain.counterFrame
        attribute = domain.attribute
        description = domain.description
    }
    
    func toDomain() -> Move {
        Move(
            id: id,
            sortOrder: sortOrder,
            characterName: characterName,
            section: section,
            skillNameEN: skillNameEN,
            skillNameKR: skillNameKR,
            skillNickname: skillNickname,
            command: command,
            judgment: judgment,
            damage: damage,
            startupFrame: startupFrame,
            guardFrame: guardFrame,
            hitFrame: hitFrame,
            counterFrame: counterFrame,
            attribute: attribute,
            description: description
        )
    }
    
    func update(_ entity: MoveEntity) {
        entity.characterName = characterName
        entity.section = section
        entity.skillNameEN = skillNameEN
        entity.skillNameKR = skillNameKR
        entity.skillNickname = skillNickname
        entity.command = command
        entity.judgment = judgment
        entity.damage = damage
        entity.startupFrame = startupFrame
        entity.guardFrame = guardFrame
        entity.hitFrame = hitFrame
        entity.counterFrame = counterFrame
        entity.attribute = attribute
        entity.descriptions = description
    }
    
    @discardableResult
    func toEntity(context: NSManagedObjectContext) -> MoveEntity {
        let entity = MoveEntity(context: context)
        entity.id = id
        entity.characterName = characterName
        entity.section = section
        entity.skillNameEN = skillNameEN
        entity.skillNameKR = skillNameKR
        entity.skillNickname = skillNickname
        entity.command = command
        entity.judgment = judgment
        entity.damage = damage
        entity.startupFrame = startupFrame
        entity.guardFrame = guardFrame
        entity.hitFrame = hitFrame
        entity.counterFrame = counterFrame
        entity.attribute = attribute
        entity.descriptions = description
        return entity
    }
}
