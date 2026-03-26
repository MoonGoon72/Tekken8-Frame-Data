//
//  MockSupabaseManager.swift
//  SupabaseAPITests
//

import Foundation

final class MockSupabaseManager: SupabaseManageable {
    func fetchFrameDataVersion() async throws -> Int {
        return 1
    }
    
    func fetchTekkenVersion() async throws -> String {
        return "1"
    }
    
    func imageURL(character: String) throws -> URL {
        return URL(string: "character")!
    }
    
    func fetchCharacter() async throws -> [Character] {
        [Character(id: 1, nameEN: "nina", nameKR: "니나", imageURL: "imagePath")]
    }
    
    func fetchMoves(characterName name: String) async throws -> [Move] {
        [Move(id: 1, sortOrder: 1, characterName: "nina", section: "일반", skillNameEN: "skillName", skillNameKR: "기술명", skillNickname: "기술 별명", command: "lp", judgment: "상", damage: "14", startupFrame: "10", guardFrame: "+1", hitFrame: "+5", counterFrame: "+7", attribute: nil, description: nil)]
    }
    
    func fetchVersion() async throws -> Int {
        2
    }
}
