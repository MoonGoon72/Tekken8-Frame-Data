//
//  TekkenVersion.swift
//  TK8
//

import Foundation

struct TekkenVersion: Decodable {
    let id: Int
    let version: String
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case version
        case updatedAt = "updated_at"
    }
}
