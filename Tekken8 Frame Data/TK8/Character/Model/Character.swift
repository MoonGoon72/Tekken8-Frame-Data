//
//  Character.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Character: Decodable, Hashable {
    let id: Int64
    let nameEN: String
    let nameKR: String
    let imageURL: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case nameEN = "name_en"
        case nameKR = "name_kr"
        case imageURL = "image_url"
    }
}
