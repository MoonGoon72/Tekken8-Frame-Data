//
//  FrameDataVersionManager.swift
//  TK8
//
//  Created by 문영균 on 5/3/25.
//

import Foundation

final class VersionManager: VersionManageable {
    private static let currentDataSchemaVersion = 2
    private let store: UserDefaults
    private let supabaseManager: SupabaseManageable
    private let coreDataManager: CoreDataManageable
    
    init(store: UserDefaults = .standard, manager: SupabaseManageable, coreData: CoreDataManageable) {
        self.store = store
        supabaseManager = manager
        coreDataManager = coreData
    }
    
    private var isRefreshing = false

    @MainActor
    func checkFrameDataVersion() async throws {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let serverVersion = try await supabaseManager.fetchFrameDataVersion()
        let localVersion = store.integer(forKey: Constants.Texts.version)
        let localSchema = store.integer(forKey: Constants.Texts.localDataSchemaVersion)
        guard serverVersion > localVersion || localSchema < Self.currentDataSchemaVersion else { return }
        guard serverVersion >= localVersion else { return }

        let tekkenVersion = try await supabaseManager.fetchTekkenVersion()
        let characters = try await supabaseManager.fetchCharacter()
        guard !characters.isEmpty,
              Set(characters.map(\.id)).count == characters.count,
              Set(characters.map(\.nameEN)).count == characters.count else {
            throw FrameDataRefreshError.invalidCharacters
        }

        var moves: [Move] = []
        var moveIDs = Set<Int64>()
        for character in characters {
            try Task.checkCancellation()
            let downloaded = try await supabaseManager.fetchMoves(characterName: character.nameEN)
            guard !downloaded.isEmpty,
                  downloaded.allSatisfy({ $0.characterName == character.nameEN && moveIDs.insert($0.id).inserted }) else {
                throw FrameDataRefreshError.invalidMoves(character.nameEN)
            }
            moves.append(contentsOf: downloaded)
        }

        guard try await supabaseManager.fetchFrameDataVersion() == serverVersion else {
            throw FrameDataRefreshError.versionChangedDuringDownload
        }
        try Task.checkCancellation()
        try await coreDataManager.replaceFrameData(characters: characters, moves: moves)
        store.set(serverVersion, forKey: Constants.Texts.version)
        store.set(tekkenVersion, forKey: Constants.Texts.tekkenVersion)
        store.set(Self.currentDataSchemaVersion, forKey: Constants.Texts.localDataSchemaVersion)
        NotificationCenter.default.post(name: .frameDataReplaced, object: nil)
    }
}

enum FrameDataRefreshError: Error, Equatable {
    case invalidCharacters
    case invalidMoves(String)
    case versionChangedDuringDownload
}

private enum Constants {
    enum Texts {
        static let version = "Version"
        static let tekkenVersion = "TekkenVersion"
        static let localDataSchemaVersion = "LocalDataSchemaVersion"
    }
}
