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
    
    func fetchFrame() async throws -> [Move] {
        let moves: [Move] = try await client
            .from("move")
            .select()
            .execute()
            .value
        return moves
    }
}
