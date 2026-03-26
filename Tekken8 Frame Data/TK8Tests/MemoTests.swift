//
//  MemoTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class MemoRepositoryTests: XCTestCase {
    var sut: DefaultMemoRepository!
    var coreDataManager: InMemoryCoreDataManager!

    override func setUp() {
        super.setUp()
        coreDataManager = InMemoryCoreDataManager()
        sut = DefaultMemoRepository(coreDataManager: coreDataManager)
    }

    override func tearDown() {
        sut = nil
        coreDataManager = nil
        super.tearDown()
    }

    // TODO(human): 아래 테스트 케이스들을 구현해주세요.
    // 힌트: save → fetchMemos 순서로 실제 동작을 검증합니다.

    func test_save_저장_후_fetchMemos_에서_조회됨() throws {
        // given
        let memos = [Memo(
            id: UUID(),
            characterName: "Nina",
            title: "니나 오로성",
            body: "쉐캔을 잘해야함",
            updatedAt: Date()
        ), Memo(
            id: UUID(),
            characterName: "Steve",
            title: "스티브 오로성",
            body: "위빙 잘하기",
            updatedAt: Date()
        )
        ]
        // when
        try memos.forEach { XCTAssertNoThrow(try sut.save(character: $0.characterName, title: $0.title, body: $0.body)) }
        // then
        let count = try sut.fetchMemos().count
        XCTAssertEqual(count, 2)
    }

    func test_fetchMemos_저장_없으면_빈_배열_반환() throws {
        // given & when
        let count = try sut.fetchMemos().count

        // then
        XCTAssertEqual(count, 0)
    }

    func test_update_수정_후_변경된_내용_반영() throws {
        // given: 저장 후 fetch해서 memo를 가져오고
        try sut.save(character: "Nina", title: "오로성", body: "쉐켄 잘하기")
        var prevMemo = try sut.fetchMemos().first!
        // when: update 호출하고
        prevMemo.body = "아이보리 많이 쓰기"
        try sut.update(memo: prevMemo)
        // then: 다시 fetch했을 때 바뀐 내용이 반영됨
        let currentMemo = try sut.fetchMemos().first!
        XCTAssertEqual(currentMemo.body, prevMemo.body)
        XCTAssertNotEqual(currentMemo.updatedAt, prevMemo.updatedAt)
    }

    func test_delete_삭제_후_fetchMemos_에서_사라짐() throws {
        // given
        let tmp = [Memo(
            id: UUID(),
            characterName: "Nina",
            title: "니나 오로성",
            body: "쉐캔을 잘해야함",
            updatedAt: Date()
        ), Memo(
            id: UUID(),
            characterName: "Steve",
            title: "스티브 오로성",
            body: "위빙 잘하기",
            updatedAt: Date()
        )
        ]
        try tmp.forEach { XCTAssertNoThrow(try sut.save(character: $0.characterName, title: $0.title, body: $0.body)) }
        let memos = try sut.fetchMemos()
        let willDeleteMemo = memos[0]
        // when
        try sut.delete(memo: willDeleteMemo)
        // then
        let result = try sut.fetchMemos()
        XCTAssertEqual(result.filter { $0.id == willDeleteMemo.id }.count, 0)
    }
}
