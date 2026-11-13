//
//  CharacterRepositoryTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class CharacterRepositoryTests: XCTestCase {
    @MainActor
    func testFailedCacheSaveRemovesInsertedCharacterAndPreservesPendingMemo() async throws {
        let cache = InMemoryCoreDataManager()
        let memo = MemoEntity(context: cache.context)
        memo.id = UUID()
        memo.body = "pending"
        cache.saveError = URLError(.cannotWriteToFile)
        let remote = CharacterRepositorySupabaseStub()
        remote.characters = [Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "")]
        let repository = DefaultCharacterRepository(manager: remote, coreData: cache)

        do {
            _ = try await repository.fetchCharacters()
            XCTFail("Expected save failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cannotWriteToFile)
        }

        XCTAssertTrue(try cache.fetch(CharacterEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(memo.isInserted)
        XCTAssertEqual(memo.body, "pending")

        cache.saveError = nil
        let characters = try await repository.fetchCharacters()
        XCTAssertEqual(characters, remote.characters)
        XCTAssertEqual(try cache.fetch(CharacterEntity.fetchRequest()).map(\.id), [1])
    }

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

    func test_characterImageURL_acceptsHTTPURL() throws {
        let expectedURL = URL(string: "http://example.com/bob.png")!
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
        let invalidImageURLs = [
            "imagePath",
            "",
            "ftp://example.com/bob.png",
            "file:///tmp/bob.png"
        ]

        for imageURL in invalidImageURLs {
            let character = Character(id: 1, nameEN: "Bob", nameKR: "밥", imageURL: imageURL)
            let repository = DefaultCharacterRepository(
                manager: CharacterRepositorySupabaseStub(),
                coreData: InMemoryCoreDataManager()
            )

            XCTAssertThrowsError(
                try repository.characterImageURL(character: character),
                "Expected \(imageURL) to be rejected"
            )
        }
    }
}

private final class CharacterRepositorySupabaseStub: SupabaseManageable {
    func fetchMoveVideos(characterName: String) async throws -> [MoveVideoRemoteRecord] { [] }
    var characters: [Character] = []
    func fetchCharacter() async throws -> [Character] { characters }
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
    func fetchFrameDataVersion() async throws -> Int { 0 }
    func fetchTekkenVersion() async throws -> String { "" }
}
