//
//  CharacterRepositoryTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class CharacterRepositoryTests: XCTestCase {
    func test_characterImageURL_usesImageURLFromCharacter() throws {
        let expectedURL = URL(string: "https://drive.google.com/uc?export=view&id=example")!
        let character = Character(
            id: 1,
            nameEN: "Bob",
            nameKR: "밥",
            imageURL: expectedURL.absoluteString
        )
        let repository = DefaultCharacterRepository(
            manager: CharacterRepositorySupabaseStub(),
            coreData: InMemoryCoreDataManager()
        )

        XCTAssertEqual(try repository.characterImageURL(character: character), expectedURL)
    }

    func test_characterImageURL_rejectsNonHTTPURL() {
        let character = Character(id: 1, nameEN: "Bob", nameKR: "밥", imageURL: "imagePath")
        let repository = DefaultCharacterRepository(
            manager: CharacterRepositorySupabaseStub(),
            coreData: InMemoryCoreDataManager()
        )

        XCTAssertThrowsError(try repository.characterImageURL(character: character))
    }
}

private final class CharacterRepositorySupabaseStub: SupabaseManageable {
    func fetchCharacter() async throws -> [Character] { [] }
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
    func fetchFrameDataVersion() async throws -> Int { 0 }
    func fetchTekkenVersion() async throws -> String { "" }
}
