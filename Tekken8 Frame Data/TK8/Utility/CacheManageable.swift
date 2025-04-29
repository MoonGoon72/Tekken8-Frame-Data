//
//  CacheManageable.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/29/25.
//

import Foundation

protocol CacheManageable {
    associatedtype DataType
    func fetch(for key: String) async -> DataType?
    func save(_ data: DataType, for key: String)
}
