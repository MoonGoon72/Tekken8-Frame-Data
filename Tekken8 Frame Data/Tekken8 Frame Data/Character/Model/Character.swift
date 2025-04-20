//
//  Character.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Character: Decodable, Hashable {
    let id: Int64
    let name: String
    let imageURL: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageURL = "image_url"
    }
}
