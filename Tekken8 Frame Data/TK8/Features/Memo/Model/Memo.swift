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

    var rawBody: String {
        // Notes written by the editor store the title followed by a newline and the body.
        // Older or imported values without that prefix are already body text.
        guard let prefix = body.range(of: title, options: [.anchored, .literal]),
              prefix.upperBound < body.endIndex,
              body[prefix.upperBound].isNewline else {
            if title.isEmpty, body.first?.isNewline == true {
                return String(body.dropFirst())
            }
            return body
        }
        return String(body[body.index(after: prefix.upperBound)...])
    }

    func hasSameContent(title: String, body: String) -> Bool {
        self.title.utf8.elementsEqual(title.utf8) && self.body.utf8.elementsEqual(body.utf8)
    }

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
