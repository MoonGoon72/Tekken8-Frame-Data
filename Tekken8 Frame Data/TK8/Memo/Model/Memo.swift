//
//  Memo.swift
//  TK8
//

import Foundation

struct Memo: Hashable {
    let id: UUID
    var characterName: String
    var title: String
    var body: String
    var isPinned: Bool
    var updatedAt: Date

    static func ==(lhs: Memo, rhs: Memo) -> Bool {
        return lhs.id == rhs.id
        && lhs.characterName == rhs.characterName
        && lhs.title == rhs.title
        && lhs.body == rhs.body
        && lhs.isPinned == rhs.isPinned
        && lhs.updatedAt == rhs.updatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(characterName)
        hasher.combine(title)
        hasher.combine(body)
        hasher.combine(isPinned)
        hasher.combine(updatedAt)
    }
}
