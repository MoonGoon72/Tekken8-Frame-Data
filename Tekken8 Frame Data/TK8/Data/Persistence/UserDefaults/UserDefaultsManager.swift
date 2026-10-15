//
//  UserDefaultsManager.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

final class UserDefaultsManager: UserDefaultsManageable {
    private let store: UserDefaults
    
    init(store: UserDefaults = .standard) {
        self.store = store
    }
    
    func fetch<T>(_ type: T.Type, forKey key: String) throws -> T? where T : Decodable {
        guard let data = store.data(forKey: key) else { return nil }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
    func update<T>(_ value: T, forKey key: String) throws where T : Encodable {
        let data = try JSONEncoder().encode(value)
        store.set(data, forKey: key)
    }
}
