//
//  MoveRepositoryTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class MoveRepositoryTests: XCTestCase {
    @MainActor
    func testMoveResponseAfterReplacementReadsSortedCacheForRequestedCharacter() async throws {
        let cache = InMemoryCoreDataManager()
        let remote = MoveRepositorySupabaseStub()
        remote.beforeMoveResponse = {
            try await cache.replaceFrameData(characters: [], moves: [
                makeMove(id: 3, sortOrder: 2),
                makeMove(id: 4, sortOrder: 1),
                makeMove(id: 5, sortOrder: 0, character: "Alisa"),
            ])
        }
        let repository = DefaultMoveRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        let moves = try await repository.fetchMoves(characterName: "King")
        XCTAssertEqual(moves.map(\.id), [4, 3])

        remote.beforeMoveResponse = { XCTFail("A cache hit should skip the remote request") }
        let cachedMoves = try await repository.fetchMoves(characterName: "King")
        XCTAssertEqual(cachedMoves.map(\.id), [4, 3])
    }

    @MainActor
    func testMoveResponseDuringReplacementSkipsCacheWrite() async throws {
        let cache = InMemoryCoreDataManager()
        let remote = MoveRepositorySupabaseStub()
        remote.beforeMoveResponse = {
            cache.isReplacingFrameData = true
            cache.saveError = URLError(.cannotWriteToFile)
        }
        let repository = DefaultMoveRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        let moves = try await repository.fetchMoves(characterName: "King")
        XCTAssertEqual(moves.map(\.id), [1])
        XCTAssertTrue(try cache.fetch(MoveEntity.fetchRequest()).isEmpty)
    }

    @MainActor
    func testFailedMoveCacheWriteRestoresUpdatedMoveAndPreservesPendingMemo() async throws {
        let cache = InMemoryCoreDataManager()
        let remote = MoveRepositorySupabaseStub()
        remote.beforeMoveResponse = {
            let original = makeMove(id: 1, sortOrder: 1)
            MoveDTO(domain: original).toEntity(context: cache.context)
            try cache.saveContext()
            let memo = MemoEntity(context: cache.context)
            memo.id = UUID()
            memo.body = "pending"
            cache.saveError = URLError(.cannotWriteToFile)
        }
        remote.moves.append(makeMove(id: 2, sortOrder: 2))
        let repository = DefaultMoveRepository(manager: remote, cache: FrameDataCache(coreData: cache))

        do {
            _ = try await repository.fetchMoves(characterName: "King")
            XCTFail("Expected save failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cannotWriteToFile)
        }

        remote.beforeMoveResponse = { XCTFail("The restored move should satisfy the cache read") }
        let moves = try await repository.fetchMoves(characterName: "King")
        XCTAssertEqual(moves.map(\.id), [1])
        XCTAssertNil(moves.first?.command)
        let memo = try XCTUnwrap(cache.fetch(MemoEntity.fetchRequest()).first)
        XCTAssertTrue(memo.isInserted)
        XCTAssertEqual(memo.body, "pending")
    }

    @MainActor
    func testFailedMoveCacheWritePreservesPendingMemoAndAllowsRetry() async throws {
        let cache = InMemoryCoreDataManager()
        let memo = MemoEntity(context: cache.context)
        memo.id = UUID()
        memo.body = "pending"
        cache.saveError = URLError(.cannotWriteToFile)
        let repository = DefaultMoveRepository(manager: MoveRepositorySupabaseStub(), cache: FrameDataCache(coreData: cache))

        do {
            _ = try await repository.fetchMoves(characterName: "King")
            XCTFail("Expected save failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cannotWriteToFile)
        }

        XCTAssertTrue(try cache.fetch(MoveEntity.fetchRequest()).isEmpty)
        XCTAssertTrue(memo.isInserted)
        XCTAssertEqual(memo.body, "pending")

        cache.saveError = nil
        let moves = try await repository.fetchMoves(characterName: "King")
        XCTAssertEqual(moves.map(\.id), [1])
        XCTAssertEqual(try cache.fetch(MoveEntity.fetchRequest()).map(\.id), [1])
    }
}

private final class MoveRepositorySupabaseStub: SupabaseManageable {
    var beforeMoveResponse: (@MainActor () async throws -> Void)?
    var moves = [makeMove(id: 1, sortOrder: 1, command: "rp")]

    func fetchMoves(characterName: String) async throws -> [Move] {
        try await beforeMoveResponse?()
        return moves
    }

    func fetchCharacter() async throws -> [Character] { [] }
    func fetchFrameDataVersion() async throws -> Int { 0 }
    func fetchTekkenVersion() async throws -> String { "" }
    func fetchMoveVideos(characterName: String) async throws -> [MoveVideoRemoteRecord] { [] }
}

private func makeMove(id: Int64, sortOrder: Double, character: String = "King", command: String? = nil) -> Move {
    Move(
        id: id, sortOrder: sortOrder, characterName: character, section: "일반",
        skillNameEN: nil, skillNameKR: nil, skillNickname: nil, command: command,
        judgment: nil, damage: nil, startupFrame: nil, guardFrame: nil, hitFrame: nil,
        counterFrame: nil, attribute: nil, description: nil
    )
}
