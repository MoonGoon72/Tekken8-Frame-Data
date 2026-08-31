//
//  SupabaseManager.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/10/25.
//

import Foundation
import PostgREST
import Supabase

enum SupabaseVersionError: LocalizedError, Equatable {
    case emptyFrameDataVersion
    case emptyTekkenVersion

    var errorDescription: String? {
        switch self {
        case .emptyFrameDataVersion:
            "frame_data_version 응답이 비어 있습니다."
        case .emptyTekkenVersion:
            "tekken_version 응답이 비어 있습니다."
        }
    }
}

final class SupabaseManager: SupabaseManageable {
    private let client: SupabaseClient
    
    init() {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
        else { fatalError("API_KEY not found in Info.plist") }
        
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: urlString)
        else { fatalError("Invalid or missing SUPABASE_URL.") }
        
        client = SupabaseClient(supabaseURL: url, supabaseKey: apiKey)
    }
    
    func fetchCharacter() async throws -> [Character] {
        let characters: [Character] = try await client
            .from("character")
            .select()
            .execute()
            .value
        return characters
    }
    
    func fetchMoves(characterName name: String) async throws -> [Move] {
        let moves: [Move] = try await client
            .from("move")
            .select()
            .eq("character_name", value: name)
            .order("sort_order")
            .execute()
            .value
        return moves
    }
    
    func fetchFrameDataVersion() async throws -> Int {
        let version: [FrameDataVersion] = try await client
            .from("frame_data_version")
            .select()
            .execute()
            .value
        guard let version = version.first else {
            throw SupabaseVersionError.emptyFrameDataVersion
        }
        return version.version
    }
    
    func fetchTekkenVersion() async throws -> String {
        let version: [TekkenVersion] = try await client
            .from("tekken_version")
            .select()
            .execute()
            .value
        guard let version = version.first else {
            throw SupabaseVersionError.emptyTekkenVersion
        }
        return version.version
    }
    
}
