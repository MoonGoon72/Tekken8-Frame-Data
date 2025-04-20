//
//  MoveDTO.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/20/25.
//

import CoreData

struct MoveDTO {
    let id: Int64
    let characterName: String
    let section: String
    let skillName: String?
    let skillNickname: String?
    let command: String?
    let judgment: String?
    let damage: String?
    let startup: String?
    let guardFrame: String?
    let hit: String?
    let counter: String?
    let additionalInfo: String?
    
    
    init(entity: MoveEntity) {
        id = entity.id
        characterName = entity.characterName ?? "알 수 없음"
        section = entity.section ?? "알 수 없는 섹션"
        skillName = entity.skillName
        skillNickname = entity.skillNickname
        command = entity.command
        judgment = entity.judgment
        damage = entity.damage
        startup = entity.startup
        guardFrame = entity.guardFrame
        hit = entity.hit
        counter = entity.counter
        additionalInfo = entity.additionalInfo
    }
    
    init(domain: Move) {
        id = Int64(domain.id)
        characterName = domain.characterName
        section = domain.section
        skillName = domain.skillName
        skillNickname = domain.skillNickname
        command = domain.command
        judgment = domain.judgment
        damage = domain.damage
        startup = domain.startup
        guardFrame = domain.guardFrame
        hit = domain.hit
        counter = domain.counter
        additionalInfo = domain.additionalInfo
    }
    
    func toDomain() -> Move {
        Move(
            id: id,
            characterName: characterName,
            section: section,
            skillName: skillName,
            skillNickname: skillNickname,
            command: command,
            judgment: judgment,
            damage: damage,
            startup: startup,
            guardFrame: guardFrame,
            hit: hit,
            counter: counter,
            additionalInfo: additionalInfo
        )
    }
    
    @discardableResult
    func toEntity(context: NSManagedObjectContext) -> MoveEntity {
        let entity = MoveEntity(context: context)
        entity.id = id
        entity.characterName = characterName
        entity.section = section
        entity.skillName = skillName
        entity.skillNickname = skillNickname
        entity.command = command
        entity.judgment = judgment
        entity.damage = damage
        entity.startup = startup
        entity.guardFrame = guardFrame
        entity.hit = hit
        entity.counter = counter
        entity.additionalInfo = additionalInfo
        return entity
    }
}
