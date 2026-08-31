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

        XCTAssertEqual(coreData.deleteAllCallCount, 0)
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

        XCTAssertEqual(coreData.deleteAllCallCount, 0)
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

        XCTAssertEqual(coreData.deleteAllCallCount, 1)
        XCTAssertEqual(store.integer(forKey: "Version"), 2)
        XCTAssertEqual(store.string(forKey: "TekkenVersion"), "2.1.0")
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

    func fetchCharacter() async throws -> [Character] { [] }
    func fetchMoves(characterName: String) async throws -> [Move] { [] }
}

private final class RecordingCoreDataManager: CoreDataManageable {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    private(set) var deleteAllCallCount = 0

    func saveContext() throws {}
    func fetch<Entity: NSManagedObject>(_ request: NSFetchRequest<Entity>) throws -> [Entity] { [] }
    func delete(_ object: NSManagedObject) {}

    func deleteAll() throws {
        deleteAllCallCount += 1
    }
}
