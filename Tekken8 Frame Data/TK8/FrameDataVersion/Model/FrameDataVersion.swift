//
//  FrameDataVersion.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

struct FrameDataVersion: Decodable {
    let id: Int
    let version: Int
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case version = "version_number"
        case updatedAt = "updated_at"
    }
}
