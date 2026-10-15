//
//  FrameDataVersionManager.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

final class VersionManager: VersionManageable {
    private static let currentDataSchemaVersion = 1
    private let store: UserDefaults
    private let supabaseManager: SupabaseManageable
    private let coreDataManager: CoreDataManageable
    
    init(store: UserDefaults = .standard, manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.store = store
        supabaseManager = manager
        coreDataManager = coreData
    }
    
    func invalidateCacheIfAppUpdated() throws {
        let saved = store.integer(forKey: Constants.Texts.localDataSchemaVersion)
        if saved < Self.currentDataSchemaVersion {
            try coreDataManager.deleteAll()
            store.set(Self.currentDataSchemaVersion, forKey: Constants.Texts.localDataSchemaVersion)
            NotificationCenter.default.post(name: .allDatabaseDeleted, object: nil)
        }
    }

    func checkFrameDataVersion() async throws {
        let localVersion = fetchLocalVersion()
        let serverVersion = try await supabaseManager.fetchFrameDataVersion()
        
        if localVersion < serverVersion {
            let tekkenVersion = try await supabaseManager.fetchTekkenVersion()
            try coreDataManager.deleteAll()
            updateLocalVersion(version: serverVersion)
            updateTekkenVersion(version: tekkenVersion)
            NotificationCenter.default.post(name: .allDatabaseDeleted, object: nil)
        }
    }

    private func updateTekkenVersion(version: String) {
        store.set(version, forKey: Constants.Texts.tekkenVersion)
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
        static let version = "Version"
        static let tekkenVersion = "TekkenVersion"
        static let localDataSchemaVersion = "LocalDataSchemaVersion"
    }
}
