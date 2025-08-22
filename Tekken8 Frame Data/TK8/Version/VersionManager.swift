//
//  FrameDataVersionManager.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

final class VersionManager: VersionManageable {
    private let store: UserDefaults
    private let supabaseManager: SupabaseManageable
    private let coreDataManager: CoreDataManageable
    
    init(store: UserDefaults = .standard, manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.store = store
        supabaseManager = manager
        coreDataManager = coreData
    }
    
    func checkFrameDataVersion() async throws {
        let localVersion = fetchLocalVersion()
        let serverVesion = try await supabaseManager.fetchFrameDataVersion()
        
        if localVersion == 1 {
            updateLocalVersion(version: serverVesion)
            return
        }
        
        if localVersion < serverVesion {
            try coreDataManager.deleteAll()
            updateLocalVersion(version: serverVesion)
            NotificationCenter.default.post(name: .allDatabaseDeleted, object: nil)
        }
    }
    
    func checkTekkenVersion() async throws {
        let tekkenVersion = try await supabaseManager.fetchTekkenVersion()
        
        updateTekkenVersion(version: tekkenVersion)
    }
    
    private func fetchLocalVersion() -> Int {
        store.integer(forKey: Constants.Texts.version)
    }
    
    private func updateLocalVersion(version: Int) {
        store.set(version, forKey: Constants.Texts.version)
    }
    
    private func updateTekkenVersion(version: String) {
        store.set(version, forKey: Constants.Texts.tekkenVersion)
    }
}

private enum Constants {
    enum Texts {
        static let version = "Version"
        static let tekkenVersion = "TekkenVersion"
    }
}
