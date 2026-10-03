@testable import TK8
import XCTest

final class MoveVideoRepositoryTests: XCTestCase {
    func test_remoteRecordDecodesStableKeyAndRelatedMoveID() throws {
        let json = """
        {
          "character_name": "Steve",
          "move_key": "steve-004",
          "object_key": "Steve/Eraser.mp4",
          "video_revision": null,
          "enabled": true,
          "move": { "id": 5648 }
        }
        """.data(using: .utf8)!

        let record = try JSONDecoder().decode(MoveVideoRemoteRecord.self, from: json)

        XCTAssertEqual(record.moveKey, "steve-004")
        XCTAssertEqual(record.move?.id, 5648)
        XCTAssertTrue(record.enabled)
    }

    func test_videoURLBuilderEncodesEachObjectPathSegment() throws {
        let builder = ConfiguredMoveVideoURLBuilder(baseURL: URL(string: "https://media.example/clips")!)

        let url = try builder.playbackURL(for: "Steve/Move #1.mp4")

        XCTAssertEqual(url.absoluteString, "https://media.example/clips/Steve/Move%20%231.mp4")
    }

    func test_videoURLBuilderRejectsInsecureOrMalformedInputs() {
        let insecureBuilder = ConfiguredMoveVideoURLBuilder(baseURL: URL(string: "http://media.example")!)
        XCTAssertThrowsError(try insecureBuilder.playbackURL(for: "Steve/Move.mp4")) {
            XCTAssertEqual($0 as? MoveVideoRepositoryError, .invalidPlaybackBaseURL)
        }

        let secureBuilder = ConfiguredMoveVideoURLBuilder(baseURL: URL(string: "https://media.example")!)
        XCTAssertThrowsError(try secureBuilder.playbackURL(for: "Steve/../Other.mp4")) {
            XCTAssertEqual($0 as? MoveVideoRepositoryError, .invalidObjectKey("Steve/../Other.mp4"))
        }
    }

    func test_defaultRepositoryMapsOnlyEnabledRowsThroughMoveID() async throws {
        let source = StubMoveVideoRemoteDataSource(records: [
            remoteRecord(moveID: 42, moveKey: "steve-001", objectKey: "Steve/Confirmed.mp4", enabled: true),
            remoteRecord(moveID: 43, moveKey: "steve-002", objectKey: "Steve/Unconfirmed.mp4", enabled: false)
        ])
        let repository = DefaultMoveVideoRepository(
            dataSource: source,
            urlBuilder: ConfiguredMoveVideoURLBuilder(baseURL: URL(string: "https://media.example")!)
        )

        let references = try await repository.fetchVideos(characterName: "Steve")

        XCTAssertEqual(Array(references.keys), [42])
        XCTAssertEqual(references[42]?.objectKey, "Steve/Confirmed.mp4")
        XCTAssertEqual(references[42]?.revision, "revision-1")
        XCTAssertEqual(references[42]?.playbackURL?.absoluteString, "https://media.example/Steve/Confirmed.mp4")
    }

    func test_defaultRepositoryKeepsMetadataWhenPlaybackBaseIsNotConfigured() async throws {
        let source = StubMoveVideoRemoteDataSource(records: [
            remoteRecord(moveID: 42, moveKey: "steve-001", objectKey: "Steve/Confirmed.mp4", enabled: true)
        ])
        let repository = DefaultMoveVideoRepository(
            dataSource: source,
            urlBuilder: ConfiguredMoveVideoURLBuilder(baseURL: nil)
        )

        let references = try await repository.fetchVideos(characterName: "Steve")

        XCTAssertEqual(references.count, 1)
        XCTAssertNil(references[42]?.playbackURL)
    }

    func test_defaultRepositoryRejectsTraversalObjectKeyWithoutPublicBaseURL() async {
        let source = StubMoveVideoRemoteDataSource(records: [
            remoteRecord(moveID: 42, moveKey: "steve-001", objectKey: "Steve/../private.mp4", enabled: true)
        ])
        let repository = DefaultMoveVideoRepository(
            dataSource: source,
            urlBuilder: ConfiguredMoveVideoURLBuilder(baseURL: nil)
        )

        do {
            _ = try await repository.fetchVideos(characterName: "Steve")
            XCTFail("Expected an invalid object key error")
        } catch {
            XCTAssertEqual(error as? MoveVideoRepositoryError, .invalidObjectKey("Steve/../private.mp4"))
        }
    }

    func test_playbackURLProviderUsesPublicURLWithoutCallingRemoteSource() async throws {
        let reference = MoveVideoReference(
            moveID: 42,
            objectKey: "Steve/Confirmed.mp4",
            revision: nil,
            playbackURL: URL(string: "https://media.example/Steve/Confirmed.mp4")
        )
        let source = StubPlaybackURLDataSource()

        let url = try await DefaultMoveVideoPlaybackURLProvider(dataSource: source).playbackURL(for: reference)

        XCTAssertEqual(url.absoluteString, "https://media.example/Steve/Confirmed.mp4")
        let callCount = await source.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func test_playbackURLProviderResolvesPrivateReferenceOnDemand() async throws {
        let reference = MoveVideoReference(
            moveID: 42,
            objectKey: "Steve/Confirmed.mp4",
            revision: nil,
            playbackURL: nil
        )
        let source = StubPlaybackURLDataSource()

        let url = try await DefaultMoveVideoPlaybackURLProvider(dataSource: source).playbackURL(for: reference)

        XCTAssertEqual(url.absoluteString, "https://signed.example/Steve/Confirmed.mp4")
        let callCount = await source.callCount()
        XCTAssertEqual(callCount, 1)
    }

    @MainActor
    func test_viewModelLoadsVideoMetadataForAnyCharacterAndKeepsFrameMovesSeparate() async {
        let videoRepository = StubMoveVideoRepository(references: [
            42: MoveVideoReference(
                moveID: 42,
                objectKey: "Nina/Confirmed.mp4",
                revision: nil,
                playbackURL: URL(string: "https://media.example/Nina/Confirmed.mp4")!
            )
        ])
        let viewModel = MoveListViewModel(
            moveRepository: EmptyMoveRepository(),
            moveVideoRepository: videoRepository
        )

        await viewModel.loadMoveVideos(characterName: "Nina")
        let fetchCount = await videoRepository.fetchCallCount()
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(viewModel.moveVideoMetadataState, .loaded)
        XCTAssertEqual(viewModel.moveVideo(for: 42)?.objectKey, "Nina/Confirmed.mp4")
        XCTAssertTrue(viewModel.filtered.isEmpty)
    }

    @MainActor
    func test_viewModelMetadataFailureDoesNotFailMoveList() async {
        let viewModel = MoveListViewModel(
            moveRepository: EmptyMoveRepository(),
            moveVideoRepository: StubMoveVideoRepository(failure: StubError.failed)
        )

        await viewModel.loadMoveVideos(characterName: "Steve")

        XCTAssertEqual(viewModel.moveVideoMetadataState, .failed)
        XCTAssertTrue(viewModel.moveVideoReferences.isEmpty)
        XCTAssertEqual(viewModel.fetchState, .idle)
    }

    @MainActor
    func test_resetMakesLateMetadataResponseStale() async {
        let repository = DelayedMoveVideoRepository()
        let viewModel = MoveListViewModel(
            moveRepository: EmptyMoveRepository(),
            moveVideoRepository: repository
        )

        let firstLoad = Task { await viewModel.loadMoveVideos(characterName: "Steve") }
        await repository.waitForRequestCount(1)
        viewModel.resetMoveVideoMetadataForNextVisit()

        let nextVisitReference = MoveVideoReference(
            moveID: 51,
            objectKey: "Steve/Next Visit.mp4",
            revision: nil,
            playbackURL: URL(string: "https://media.example/Steve/Next%20Visit.mp4")!
        )
        let secondLoad = Task { await viewModel.loadMoveVideos(characterName: "Steve") }
        await repository.waitForRequestCount(2)

        await repository.resolve(
            requestAt: 0,
            with: [42: MoveVideoReference(
                moveID: 42,
                objectKey: "Steve/Stale.mp4",
                revision: nil,
                playbackURL: URL(string: "https://media.example/Steve/Stale.mp4")!
            )]
        )
        await firstLoad.value
        XCTAssertEqual(viewModel.moveVideoMetadataState, .loading)
        XCTAssertTrue(viewModel.moveVideoReferences.isEmpty)

        await repository.resolve(requestAt: 1, with: [51: nextVisitReference])
        await secondLoad.value
        XCTAssertEqual(viewModel.moveVideoMetadataState, .loaded)
        XCTAssertEqual(viewModel.moveVideoReferences, [51: nextVisitReference])
    }
}

private struct StubMoveVideoRemoteDataSource: MoveVideoRemoteDataSource {
    let records: [MoveVideoRemoteRecord]

    func fetchMoveVideos(characterName: String) async throws -> [MoveVideoRemoteRecord] {
        records
    }
}

private actor StubPlaybackURLDataSource: MoveVideoPlaybackURLDataSource {
    private var calls = 0

    func fetchMoveVideoPlaybackURL(objectKey: String) async throws -> URL {
        calls += 1
        return URL(string: "https://signed.example/\(objectKey)")!
    }

    func callCount() -> Int { calls }
}

private actor StubMoveVideoRepository: MoveVideoRepository {
    let references: [Int64: MoveVideoReference]
    let failure: StubError?
    private var fetchCount = 0
    nonisolated var isConfigured: Bool { true }

    init(references: [Int64: MoveVideoReference] = [:], failure: StubError? = nil) {
        self.references = references
        self.failure = failure
    }

    func fetchVideos(characterName: String) async throws -> [Int64: MoveVideoReference] {
        fetchCount += 1
        if let failure { throw failure }
        return references
    }

    func fetchCallCount() -> Int { fetchCount }
}

private struct EmptyMoveRepository: MoveRepository {
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
}

private enum StubError: Error {
    case failed
}

private func remoteRecord(
    moveID: Int64,
    moveKey: String,
    objectKey: String,
    enabled: Bool
) -> MoveVideoRemoteRecord {
    MoveVideoRemoteRecord(
        characterName: "Steve",
        moveKey: moveKey,
        objectKey: objectKey,
        videoRevision: "revision-1",
        enabled: enabled,
        move: .init(id: moveID)
    )
}

private actor DelayedMoveVideoRepository: MoveVideoRepository {
    private var continuations: [Int: CheckedContinuation<[Int64: MoveVideoReference], Error>] = [:]
    private var requestCount = 0
    private var requestWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    nonisolated var isConfigured: Bool { true }

    func fetchVideos(characterName: String) async throws -> [Int64: MoveVideoReference] {
        let requestID = requestCount
        requestCount += 1
        let readyWaiters = requestWaiters.filter { $0.0 <= requestCount }
        requestWaiters.removeAll { $0.0 <= requestCount }
        readyWaiters.forEach { $0.1.resume() }
        return try await withCheckedThrowingContinuation { continuation in
            continuations[requestID] = continuation
        }
    }

    func waitForRequestCount(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { continuation in
            requestWaiters.append((count, continuation))
        }
    }

    func resolve(requestAt index: Int, with references: [Int64: MoveVideoReference]) {
        continuations.removeValue(forKey: index)?.resume(returning: references)
    }
}
