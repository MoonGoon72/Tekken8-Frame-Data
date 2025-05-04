//
//  FrameDataVersionManager.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

final class FrameDataVersionManager: FrameDataVersionManageable {
    private let store: UserDefaults
    private let supabaseManager: SupabaseManageable
    private let coreDataManager: CoreDataManageable
    
    init(store: UserDefaults = .standard, manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.store = store
        supabaseManager = manager
        coreDataManager = coreData
    }
    
    func checkVersion() async throws {
        let localVersion = fetchLocalVersion()
        let serverVesion = try await supabaseManager.fetchVersion()
        
        if localVersion < serverVesion {
            try coreDataManager.deleteAll()
            updateLocalVersion(version: serverVesion)
            NotificationCenter.default.post(name: .allDatabaseDeleted, object: nil)
        }
    }
    
    private func fetchLocalVersion() -> Int {
        store.integer(forKey: Constants.Texts.version)
    }
    
    private func updateLocalVersion(version: Int) {
        store.set(version, forKey: Constants.Texts.version)
    }
}

private enum Constants {
    enum Texts {
        static let version = "version"
        static let updatedAt = "updatedAt"
    }
}
