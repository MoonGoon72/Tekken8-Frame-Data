//
//  Character.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Character: Decodable {
    let id: Int
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
    }
}
