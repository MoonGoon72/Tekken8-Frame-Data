//
//  UserDefaultsManageable.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

protocol UserDefaultsManageable {
    func fetch<T: Decodable>(_ type: T.Type, forKey key: String) throws -> T?
    func update<T: Encodable>(_ value: T, forKey key: String) throws
}
