//
//  KRToENTranslatorTests.swift
//  TK8Tests
//

import XCTest

final class KRToENTranslatorTests: XCTestCase {

    // MARK: - Section Translation

    func test_section_히트_translates_to_Heat() {
        XCTAssertEqual(KRToENTranslator.translate("히트"), "Heat")
    }

    func test_section_레이지_translates_to_Rage() {
        XCTAssertEqual(KRToENTranslator.translate("레이지"), "Rage")
    }

    func test_section_일반_translates_to_General() {
        XCTAssertEqual(KRToENTranslator.translate("일반"), "General")
    }

    func test_section_앉은상태_translates_to_While_crouching() {
        XCTAssertEqual(KRToENTranslator.translate("앉은 상태"), "While crouching")
        XCTAssertEqual(KRToENTranslator.translate("앉은상태"), "While crouching")
    }

    func test_section_잡기_translates_to_Throw() {
        XCTAssertEqual(KRToENTranslator.translate("잡기"), "Throw")
    }

    func test_section_반격기_translates_to_Reversal() {
        XCTAssertEqual(KRToENTranslator.translate("반격기"), "Reversal")
    }

    // MARK: - Leading Context Translation

    func test_히트_상태에서_prefix() {
        let result = KRToENTranslator.translate("히트 상태에서 파워크러쉬")
        XCTAssertTrue(result.hasPrefix("During Heat"))
    }

    func test_레이지_상태에서_prefix() {
        let result = KRToENTranslator.translate("레이지 상태에서")
        XCTAssertTrue(result.hasPrefix("During Rage"))
    }

    func test_몸을_숙인_상태에서_prefix() {
        let result = KRToENTranslator.translate("몸을 숙인 상태에서 lp")
        XCTAssertTrue(result.hasPrefix("While crouching"))
    }

    func test_일어나며_prefix() {
        let result = KRToENTranslator.translate("일어나며 rp")
        XCTAssertTrue(result.hasPrefix("While rising"))
    }

    func test_상대에게_등을_보일_때_prefix() {
        let result = KRToENTranslator.translate("상대에게 등을 보일 때 lp")
        XCTAssertTrue(result.hasPrefix("Back facing opponent"))
    }

    // MARK: - Core Pattern Translation

    func test_히트_or_가드_시_translates() {
        let result = KRToENTranslator.translate("히트 or 가드 시 추가타")
        XCTAssertTrue(result.contains("on hit or block"))
    }

    // MARK: - Fixed Dictionary Translation

    func test_레이지_아츠_translates() {
        let result = KRToENTranslator.translate("레이지 아츠")
        XCTAssertEqual(result, "Rage Art")
    }

    func test_홀드_가능_translates() {
        let result = KRToENTranslator.translate("홀드 가능")
        XCTAssertEqual(result, "can hold")
    }

    func test_잡기_풀기_불가_translates() {
        let result = KRToENTranslator.translate("잡기 풀기 불가")
        XCTAssertEqual(result, "Throw break unavailable")
    }

    func test_가드_데미지_있음_translates() {
        let result = KRToENTranslator.translate("가드 데미지 있음")
        XCTAssertEqual(result, "Chip damage on block")
    }

    func test_가드_대미지_typo_also_translates() {
        // 오탈자 교정 테스트
        let result = KRToENTranslator.translate("가드 대미지 있음")
        XCTAssertEqual(result, "Chip damage on block")
    }

    // MARK: - "도중에도 사용 가능" Pattern

    func test_도중에도_사용_가능_translates() {
        let result = KRToENTranslator.translate("횡이동 도중에도 사용 가능")
        XCTAssertEqual(result, "Also possible during Sidestep")
    }

    // MARK: - 혹은 Translation

    func test_혹은_at_start_becomes_Or() {
        let result = KRToENTranslator.translate("혹은 lp")
        XCTAssertTrue(result.hasPrefix("Or"))
    }

    // MARK: - Combined Context Translation

    func test_multiple_contexts_combined() {
        // 히트 상태에서 + 몸을 숙인 상태에서 → "During Heat, While crouching"
        let result = KRToENTranslator.translate("히트 상태에서 몸을 숙인 상태에서 lp")
        XCTAssertTrue(result.contains("During Heat"))
        XCTAssertTrue(result.contains("While crouching"))
    }

    // MARK: - Input Pattern Translation

    func test_입력_시_캔슬_translates() {
        let result = KRToENTranslator.translate("rp 입력 시 캔슬")
        XCTAssertEqual(result, "rp to cancel")
    }

    func test_입력_시_공격_캔슬_translates() {
        let result = KRToENTranslator.translate("lp 입력 시 공격을 캔슬")
        XCTAssertEqual(result, "lp to cancel attack")
    }

    // MARK: - TODO(human): Edge Case Tests

}
