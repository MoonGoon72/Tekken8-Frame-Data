//
//  Move.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Move: Decodable, Hashable {
    let id: Int
    let characterName: String
    let section: String
    let skillName: String
    let command: String
    let judgment: String
    let damage: String
    let startup: String
    let `guard`: String
    let hit: String
    let counter: String
    let additionalInfo: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case characterName = "character_name"
        case section = "section"
        case skillName = "skill_name"
        case command = "command"
        case judgment = "judgment"
        case damage = "damage"
        case startup = "startup"
        case `guard` = "guard"
        case hit = "hit"
        case counter = "counter"
        case additionalInfo = "additional_info"
    }
}
