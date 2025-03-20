//
//  SupabaseManageable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/11/25.
//

import Foundation

protocol SupabaseManageable {
    func fetchFrame() async throws -> [Move]
}
