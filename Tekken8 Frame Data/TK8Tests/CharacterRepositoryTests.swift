//
//  CharacterRepositoryTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class CharacterRepositoryTests: XCTestCase {
    @MainActor
    func testRemoteResponseAfterReplacementReadsNewCache() async throws {
        let cache = InMemoryCoreDataManager()
        let oldCharacter = Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "")
        let newCharacter = Character(id: 2, nameEN: "Jun", nameKR: "준", imageURL: "")
        let remote = CharacterRepositorySupabaseStub()
        remote.characters = [oldCharacter]
        remote.beforeResponse = {
            try await cache.replaceFrameData(characters: [newCharacter], moves: [])
        }
        let repository = DefaultCharacterRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        let characters = try await repository.fetchCharacters()
        XCTAssertEqual(characters, [newCharacter])

        remote.beforeResponse = { XCTFail("A cache hit should skip the remote request") }
        let cachedCharacters = try await repository.fetchCharacters()
        XCTAssertEqual(cachedCharacters, [newCharacter])
    }

    @MainActor
    func testRemoteResponseDuringReplacementSkipsCacheWrite() async throws {
        let cache = InMemoryCoreDataManager()
        let remote = CharacterRepositorySupabaseStub()
        remote.characters = [Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "")]
        remote.beforeResponse = { cache.isReplacingFrameData = true }
        let repository = DefaultCharacterRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        let characters = try await repository.fetchCharacters()
        XCTAssertEqual(characters, remote.characters)
        XCTAssertTrue(try cache.fetch(CharacterEntity.fetchRequest()).isEmpty)
    }

    @MainActor
    func testFailedCacheSaveRemovesInsertedCharacterAndPreservesPendingMemo() async throws {
        let cache = InMemoryCoreDataManager()
        let memo = MemoEntity(context: cache.context)
        memo.id = UUID()
        memo.body = "pending"
        cache.saveError = URLError(.cannotWriteToFile)
        let remote = CharacterRepositorySupabaseStub()
        remote.characters = [Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "")]
        let repository = DefaultCharacterRepository(manager: remote, cache: FrameDataCache(coreData: cache))

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

    @MainActor
    func testFailedCacheSaveRestoresCharacterAddedWhileRemoteRequestWasPending() async throws {
        let cache = InMemoryCoreDataManager()
        let original = Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: "https://example.com/king")
        let remote = CharacterRepositorySupabaseStub()
        remote.characters = [
            Character(id: 1, nameEN: "Updated King", nameKR: "킹", imageURL: ""),
            Character(id: 2, nameEN: "Jun", nameKR: "준", imageURL: ""),
        ]
        remote.beforeResponse = {
            _ = CharacterDTO(domain: original).toEntity(in: cache.context)
            try cache.saveContext()
            cache.saveError = URLError(.cannotWriteToFile)
        }
        let repository = DefaultCharacterRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        do {
            _ = try await repository.fetchCharacters()
            XCTFail("Expected save failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cannotWriteToFile)
        }

        remote.beforeResponse = { XCTFail("The restored character should satisfy the cache read") }
        let characters = try await repository.fetchCharacters()
        XCTAssertEqual(characters, [original])
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
            cache: FrameDataCache(coreData: InMemoryCoreDataManager())
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
            cache: FrameDataCache(coreData: InMemoryCoreDataManager())
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
                cache: FrameDataCache(coreData: InMemoryCoreDataManager())
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
    var beforeResponse: (@MainActor () async throws -> Void)?

    func fetchCharacter() async throws -> [Character] {
        try await beforeResponse?()
        return characters
    }
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
    func fetchFrameDataVersion() async throws -> Int { 0 }
    func fetchTekkenVersion() async throws -> String { "" }
}
