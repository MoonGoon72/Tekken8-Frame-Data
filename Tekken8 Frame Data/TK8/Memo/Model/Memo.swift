//
//  Memo.swift
//  TK8
//

import Foundation

struct Memo: Hashable {
    let id: UUID
    let characterName: String
    var title: String
    var body: String
    var updatedAt: Date

    static func ==(lhs: Memo, rhs: Memo) -> Bool {
        return lhs.id == rhs.id
    }
}
