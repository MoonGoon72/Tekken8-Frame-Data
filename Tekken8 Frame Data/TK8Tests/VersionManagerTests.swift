//
//  VersionManagerTests.swift
//  TK8Tests
//

@testable import TK8
import CoreData
import XCTest

final class VersionManagerTests: XCTestCase {
    private var store: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "VersionManagerTests.\(UUID().uuidString)"
        store = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        store.removePersistentDomain(forName: suiteName)
        store = nil
        suiteName = nil
        super.tearDown()
    }

    func test_checkFrameDataVersion_preservesCacheWhenFrameDataVersionIsEmpty() async {
        let coreData = RecordingCoreDataManager()
        let manager = VersionManager(
            store: store,
            manager: VersionSupabaseStub(frameDataVersionResult: .failure(.emptyFrameDataVersion)),
            coreData: coreData
        )

        await assertThrowsSupabaseVersionError(.emptyFrameDataVersion, from: manager)

        XCTAssertEqual(coreData.replacementCount, 0)
        XCTAssertEqual(store.integer(forKey: "Version"), 0)
    }

    func test_checkFrameDataVersion_preservesCacheWhenTekkenVersionIsEmpty() async {
        store.set(1, forKey: "Version")
        let coreData = RecordingCoreDataManager()
        let manager = VersionManager(
            store: store,
            manager: VersionSupabaseStub(
                frameDataVersionResult: .success(2),
                tekkenVersionResult: .failure(.emptyTekkenVersion)
            ),
            coreData: coreData
        )

        await assertThrowsSupabaseVersionError(.emptyTekkenVersion, from: manager)

        XCTAssertEqual(coreData.replacementCount, 0)
        XCTAssertEqual(store.integer(forKey: "Version"), 1)
        XCTAssertNil(store.string(forKey: "TekkenVersion"))
    }

    func test_checkFrameDataVersion_updatesVersionsAfterBothResponsesSucceed() async throws {
        store.set(1, forKey: "Version")
        let coreData = RecordingCoreDataManager()
        let manager = VersionManager(
            store: store,
            manager: VersionSupabaseStub(
                frameDataVersionResult: .success(2),
                tekkenVersionResult: .success("2.1.0")
            ),
            coreData: coreData
        )

        try await manager.checkFrameDataVersion()

        XCTAssertEqual(coreData.replacementCount, 1)
        XCTAssertEqual(store.integer(forKey: "Version"), 2)
        XCTAssertEqual(store.string(forKey: "TekkenVersion"), "2.1.0")
    }

    @MainActor
    func testInterruptedRefreshKeepsOldCacheAndRetriesWithoutDeletingMemos() async throws {
        store.set(2, forKey: "Version")
        store.set(1, forKey: "LocalDataSchemaVersion")
        store.set("old", forKey: "TekkenVersion")
        let cache = InMemoryCoreDataManager()
        let oldCharacter = Character(id: 1, nameEN: "King", nameKR: "기존", imageURL: "")
        CharacterDTO(domain: oldCharacter).toEntity(in: cache.context)
        let oldMove = MoveEntity(context: cache.context)
        oldMove.id = 1
        oldMove.characterName = "King"
        oldMove.command = "lp"
        let memo = MemoEntity(context: cache.context)
        memo.id = UUID()
        memo.body = "keep"
        try cache.saveContext()

        let remote = VersionSupabaseStub(frameDataVersionResult: .success(2))
        remote.failSecondDownload = true
        let manager = VersionManager(store: store, manager: remote, coreData: cache)
        do {
            try await manager.checkFrameDataVersion()
            XCTFail("Expected interrupted download")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .networkConnectionLost)
        }

        XCTAssertEqual(try cache.fetch(MoveEntity.fetchRequest()).map(\.command), ["lp"])
        XCTAssertEqual(try cache.fetch(CharacterEntity.fetchRequest()).map(\.nameKR), ["기존"])
        XCTAssertEqual(store.integer(forKey: "LocalDataSchemaVersion"), 1)
        XCTAssertEqual(store.string(forKey: "TekkenVersion"), "old")

        remote.failSecondDownload = false
        try await manager.checkFrameDataVersion()

        XCTAssertEqual(try cache.fetch(MoveEntity.fetchRequest()).map(\.command), ["rp", "rp"])
        XCTAssertEqual(Set(try cache.fetch(CharacterEntity.fetchRequest()).compactMap(\.nameEN)), ["King", "Alisa"])
        XCTAssertEqual(try cache.fetch(MemoEntity.fetchRequest()).map(\.body), ["keep"])
        XCTAssertEqual(store.integer(forKey: "LocalDataSchemaVersion"), 2)
        XCTAssertEqual(store.string(forKey: "TekkenVersion"), "1.0.0")
    }

    @MainActor
    func testFailedMoveCacheWritePreservesPendingMemoAndAllowsRetry() async throws {
        let cache = InMemoryCoreDataManager()
        let memo = MemoEntity(context: cache.context)
        memo.id = UUID()
        memo.body = "pending"
        cache.saveError = URLError(.cannotWriteToFile)
        let repository = DefaultMoveRepository(manager: VersionSupabaseStub(), coreData: cache)

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

    private func assertThrowsSupabaseVersionError(
        _ expectedError: SupabaseVersionError,
        from manager: VersionManager
    ) async {
        do {
            try await manager.checkFrameDataVersion()
            XCTFail("Expected \(expectedError) to be thrown")
        } catch let error as SupabaseVersionError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class VersionSupabaseStub: SupabaseManageable {
    var failSecondDownload = false
    private let frameDataVersionResult: Result<Int, SupabaseVersionError>
    private let tekkenVersionResult: Result<String, SupabaseVersionError>

    init(
        frameDataVersionResult: Result<Int, SupabaseVersionError> = .success(1),
        tekkenVersionResult: Result<String, SupabaseVersionError> = .success("1.0.0")
    ) {
        self.frameDataVersionResult = frameDataVersionResult
        self.tekkenVersionResult = tekkenVersionResult
    }

    func fetchFrameDataVersion() async throws -> Int {
        try frameDataVersionResult.get()
    }

    func fetchTekkenVersion() async throws -> String {
        try tekkenVersionResult.get()
    }

    func fetchCharacter() async throws -> [Character] {
        [Character(id: 1, nameEN: "King", nameKR: "킹", imageURL: ""),
         Character(id: 2, nameEN: "Alisa", nameKR: "알리사", imageURL: "")]
    }

    func fetchMoves(characterName: String) async throws -> [Move] {
        if characterName == "Alisa", failSecondDownload { throw URLError(.networkConnectionLost) }
        let id = characterName == "King" ? 1 : 2
        let json = """
        {"id":\(id),"sort_order":1,"character_name":"\(characterName)","section":"일반","command":"rp"}
        """
        return [try JSONDecoder().decode(Move.self, from: Data(json.utf8))]
    }
    func fetchMoveVideos(characterName: String) async throws -> [MoveVideoRemoteRecord] { [] }
}

private final class RecordingCoreDataManager: CoreDataManageable {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    private(set) var replacementCount = 0

    func saveContext() throws {}
    func fetch<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>) throws -> [Entity] { [] }
    func delete(_ object: NSManagedObject) {}

    @MainActor
    func replaceFrameData(characters: [Character], moves: [Move]) async throws {
        replacementCount += 1
    }
}
