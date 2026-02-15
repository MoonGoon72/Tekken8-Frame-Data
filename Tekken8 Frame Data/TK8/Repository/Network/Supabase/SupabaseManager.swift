//
//  SupabaseManager.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 2/10/25.
//

import Foundation
import PostgREST
import Supabase

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
        return version[0].version
    }
    
    func fetchTekkenVersion() async throws -> String {
        let version: [TekkenVersion] = try await client
            .from("tekken_version")
            .select()
            .execute()
            .value
        return version[0].version
    }
    
    func imageURL(character: String) throws -> URL {
        let url = try client.storage
            .from("Images")
            .getPublicURL(path: "characterImage/\(character).png")
        return url
    }
}
