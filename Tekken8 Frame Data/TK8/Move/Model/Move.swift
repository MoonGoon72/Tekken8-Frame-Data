//
//  Move.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Move: Decodable, Hashable {
    let id: Int64
    let characterName: String
    let section: String
    let skillNameEN: String?
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case characterName = "character_name"
        case section = "section"
        case skillNameEN = "skill_name_en"
        case skillNameKR = "skill_name_kr"
        case skillNickname = "skill_nickname"
        case command = "command"
        case judgment = "judgment"
        case damage = "damage"
        case startupFrame = "startup_frame"
        case guardFrame = "guard_frame"
        case hitFrame = "hit_frame"
        case counterFrame = "counter_frame"
        case attribute
        case description
    }
}
