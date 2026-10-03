@testable import TK8
import AVFoundation
import XCTest

@MainActor
final class MoveVideoPlaybackTests: XCTestCase {
    func test_closeDuringURLResolutionDiscardsLateSuccess() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "URL requested")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        session.stop()
        let lateChange = expectation(description: "No update after close")
        lateChange.isInverted = true
        session.onChange = { lateChange.fulfill() }
        provider.responses[0].resume(returning: URL(fileURLWithPath: "/tmp/discarded.mp4"))
        await fulfillment(of: [lateChange], timeout: 0.15)
        XCTAssertEqual(session.state, .stopped)
        XCTAssertNil(session.player)
    }

    func test_closeDuringURLResolutionDiscardsLateFailure() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "URL requested")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        session.stop()
        let lateChange = expectation(description: "No error after close")
        lateChange.isInverted = true
        session.onChange = { lateChange.fulfill() }
        provider.responses[0].resume(throwing: URLError(.notConnectedToInternet))
        await fulfillment(of: [lateChange], timeout: 0.15)
        XCTAssertEqual(session.state, .stopped)
        XCTAssertNil(session.player)
    }

    func test_failureRetryResolvesNewURLAndKeepsInitialPlaybackMuted() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "First request")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        let failed = expectation(description: "Failure displayed")
        session.onChange = { if session.state == .failed { failed.fulfill() } }
        provider.responses[0].resume(throwing: URLError(.notConnectedToInternet))
        await fulfillment(of: [failed], timeout: 2)
        let retried = expectation(description: "Fresh request")
        provider.onRequest = { retried.fulfill() }
        session.onChange = nil
        session.retry(applicationIsActive: true)
        await fulfillment(of: [retried], timeout: 2)
        let installed = expectation(description: "Player installed")
        session.onChange = { if session.player != nil { session.onChange = nil; installed.fulfill() } }
        provider.responses[1].resume(returning: URL(fileURLWithPath: "/tmp/retry.mp4"))
        await fulfillment(of: [installed], timeout: 2)
        XCTAssertTrue(session.player?.isMuted == true)
        XCTAssertEqual(provider.responses.count, 2)
        session.stop()
    }

    func test_inactivationDuringResolutionPreventsAutoplayOnLateResponse() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "URL requested")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        session.applicationWillResignActive()
        let installed = expectation(description: "Paused player installed")
        session.onChange = { if session.player != nil { session.onChange = nil; installed.fulfill() } }
        provider.responses[0].resume(returning: URL(fileURLWithPath: "/tmp/paused.mp4"))
        await fulfillment(of: [installed], timeout: 2)
        XCTAssertFalse(session.allowsAutoplay)
        XCTAssertEqual(session.player?.rate, 0)
        XCTAssertEqual(session.suspensionCount, 1)
        session.stop()
    }

    func test_repeatedAppearanceDoesNotResolveAgainOrReplacePausedPlayer() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "URL requested")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        let installed = expectation(description: "Player installed")
        session.onChange = { if session.player != nil { session.onChange = nil; installed.fulfill() } }
        provider.responses[0].resume(returning: URL(fileURLWithPath: "/tmp/same-player.mp4"))
        await fulfillment(of: [installed], timeout: 2)
        let original = session.player
        session.applicationWillResignActive()
        session.load()
        XCTAssertTrue(session.player === original)
        XCTAssertEqual(session.player?.rate, 0)
        XCTAssertEqual(provider.responses.count, 1)
        session.stop()
    }

    func test_invalidMediaReportsFailureAndStopsPlayback() async {
        let provider = DeferredVideoURLProvider()
        let requested = expectation(description: "URL requested")
        provider.onRequest = { requested.fulfill() }
        let session = makeSession(provider)
        session.load()
        await fulfillment(of: [requested], timeout: 2)
        let failed = expectation(description: "Invalid media reported")
        session.onChange = {
            if session.state == .failed { session.onChange = nil; failed.fulfill() }
        }
        provider.responses[0].resume(returning: URL(fileURLWithPath: "/tmp/" + UUID().uuidString + ".mp4"))
        await fulfillment(of: [failed], timeout: 3)
        XCTAssertEqual(session.state, .failed)
        XCTAssertEqual(session.player?.rate, 0)
        session.stop()
    }



    private func makeSession(_ provider: MoveVideoPlaybackURLProviding) -> MoveVideoPlaybackSession {
        MoveVideoPlaybackSession(reference: MoveVideoReference(moveID: 1, objectKey: "test.mp4", revision: nil, playbackURL: nil), provider: provider)
    }
}

@MainActor
private final class DeferredVideoURLProvider: MoveVideoPlaybackURLProviding {
    var onRequest: (() -> Void)?
    var responses: [CheckedContinuation<URL, Error>] = []

    func playbackURL(for reference: MoveVideoReference) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            responses.append(continuation)
            onRequest?()
        }
    }
}
