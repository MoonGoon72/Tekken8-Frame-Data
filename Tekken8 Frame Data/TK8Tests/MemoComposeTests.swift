//
//  MemoComposeTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class MemoComposeTests: XCTestCase {
    func test_newMemoAutomaticallyFocusesOnlyOnFirstAppearance() {
        var sut = MemoAutoFocusPolicy(isNewMemo: true)

        XCTAssertTrue(sut.shouldFocusOnAppearance())
        XCTAssertFalse(sut.shouldFocusOnAppearance())
    }

    func test_existingMemoNeverAutomaticallyFocuses() {
        var sut = MemoAutoFocusPolicy(isNewMemo: false)

        XCTAssertFalse(sut.shouldFocusOnAppearance())
        XCTAssertFalse(sut.shouldFocusOnAppearance())
    }
}
