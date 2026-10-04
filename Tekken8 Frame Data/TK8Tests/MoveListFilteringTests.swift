//
//  MoveListFilteringTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class MoveListFilteringTests: XCTestCase {
    private let moves: [Move] = [
        Move(
            id: 1,
            sortOrder: 1,
            characterName: "kazuya",
            section: "일반",
            skillNameEN: "Wind God Fist",
            skillNameKR: "초풍",
            skillNickname: "초풍",
            command: "6n23rp",
            judgment: "상",
            damage: "24",
            startupFrame: "11",
            guardFrame: "+5",
            hitFrame: "A",
            counterFrame: "A",
            attribute: nil,
            description: nil
        ),
        Move(
            id: 2,
            sortOrder: 2,
            characterName: "kazuya",
            section: "히트",
            skillNameEN: "Heat Smash",
            skillNameKR: "히트 스매시",
            skillNickname: nil,
            command: "rp+lk",
            judgment: "중",
            damage: "30",
            startupFrame: "15",
            guardFrame: "-12",
            hitFrame: "A",
            counterFrame: "A",
            attribute: "powercrush",
            description: nil
        ),
        Move(
            id: 3,
            sortOrder: 3,
            characterName: "kazuya",
            section: "일반",
            skillNameEN: "Spinning Demon",
            skillNameKR: "나락",
            skillNickname: nil,
            command: "6n23rk",
            judgment: "하",
            damage: "32",
            startupFrame: "20",
            guardFrame: "-14",
            hitFrame: "A",
            counterFrame: "A",
            attribute: nil,
            description: "히트 시 스크류 상태로"
        ),
        Move(
            id: 4,
            sortOrder: 4,
            characterName: "kazuya",
            section: "레이지",
            skillNameEN: "Rage Art",
            skillNameKR: "레이지 아츠",
            skillNickname: nil,
            command: "3ap",
            judgment: "중",
            damage: "55",
            startupFrame: "20",
            guardFrame: "-22",
            hitFrame: "A",
            counterFrame: "A",
            attribute: "powercrush",
            description: nil
        ),
        Move(
            id: 5,
            sortOrder: 5,
            characterName: "kazuya",
            section: "앉은 상태",
            skillNameEN: "Crouching Uppercut",
            skillNameKR: "앉아 어퍼",
            skillNickname: nil,
            command: "rp",
            judgment: "중",
            damage: "18",
            startupFrame: "13",
            guardFrame: "-15",
            hitFrame: "A",
            counterFrame: "A",
            attribute: nil,
            description: nil
        ),
    ]

    // MARK: - Command Filtering

    func test_command_filtering_finds_matching_moves() {
        // given
        let keyword = "rp"

        // when
        let filtered = moves.filter { move in
            move.command?.lowercased().contains(keyword.lowercased()) ?? false
        }

        // then
        XCTAssertEqual(filtered.count, 3)  // id: 1(6n23rp), 2(rp+lk), 5(rp)
        XCTAssertTrue(filtered.contains(where: { $0.id == 1 }))
        XCTAssertTrue(filtered.contains(where: { $0.id == 2 }))
        XCTAssertTrue(filtered.contains(where: { $0.id == 5 }))
    }

    func test_command_filtering_empty_keyword_returns_all() {
        // given
        let keyword = ""

        // when
        let filtered = keyword.isEmpty ? moves : moves.filter {
            $0.command?.lowercased().contains(keyword.lowercased()) ?? false
        }

        // then
        XCTAssertEqual(filtered.count, moves.count)
    }

    // MARK: - Attribute Filtering

    func test_attribute_filtering_powercrush() {
        // given
        let keyword = "파크"  // 파워크러쉬 줄임말

        // when
        let filtered = moves.filter { move in
            if keyword.contains("파크") || keyword.contains("파워크러쉬") || keyword.contains("powercrush") {
                return move.attribute?.contains("powercrush") ?? false
            }
            return false
        }

        // then
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.attribute == "powercrush" })
    }

    // MARK: - Skill Name Filtering

    func test_skillName_KR_filtering() {
        // given
        let keyword = "초풍"

        // when
        let filtered = moves.filter { move in
            move.skillNameKR?.lowercased().contains(keyword.lowercased()) ?? false
        }

        // then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, 1)
    }

    func test_skillName_EN_filtering() {
        // given
        let keyword = "wind"

        // when
        let filtered = moves.filter { move in
            move.skillNameEN?.lowercased().contains(keyword.lowercased()) ?? false
        }

        // then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.skillNameEN, "Wind God Fist")
    }

    // MARK: - Section Filtering

    func test_filtering_by_section() {
        // given
        let sections = ["히트", "레이지", "일반", "앉은 상태"]

        // when & then
        for section in sections {
            let filtered = moves.filter { $0.section == section }
            XCTAssertFalse(filtered.isEmpty, "\(section) 섹션에 해당하는 기술이 있어야 함")
        }
    }

    // MARK: - Frame Range Filtering

    func test_frame_range_filtering_parses_signed_values() {
        XCTAssertTrue(MoveFrameRangeMatcher.matches("+5", in: 0...30))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("-12", in: -14...(-10)))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("-12", in: 0...30))
    }

    func test_frame_range_filtering_matches_overlapping_ranges() {
        XCTAssertTrue(MoveFrameRangeMatcher.matches("10~12", in: 11...15))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("-14~-10", in: -15...(-12)))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("10~12", in: 13...15))
    }

    func test_frame_range_filtering_treats_comma_values_as_discrete_values() {
        XCTAssertTrue(MoveFrameRangeMatcher.matches("10, 21", in: 21...21))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("10, 21", in: 15...18))
    }

    func test_exact_frame_input_matches_only_the_requested_value_including_variable_frames() {
        var input = FrameFilterInput(allowsNegative: false)
        input.select(.exact, first: 15)

        XCTAssertEqual(input.selectedRange, 15...15)
        XCTAssertTrue(MoveFrameRangeMatcher.matches("15", in: input.selectedRange))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("14~16", in: input.selectedRange))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("16", in: input.selectedRange))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("10, 20", in: input.selectedRange))
    }

    func test_one_sided_input_includes_threshold_and_values_beyond_old_slider_limits() {
        var startup = FrameFilterInput(allowsNegative: false)
        startup.select(.atLeast, first: 21)
        XCTAssertTrue(MoveFrameRangeMatcher.matches("21", in: startup.selectedRange))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("60", in: startup.selectedRange))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("20", in: startup.selectedRange))

        var guardInput = FrameFilterInput(allowsNegative: true)
        guardInput.select(.atMost, first: -15)
        XCTAssertTrue(MoveFrameRangeMatcher.matches("-15", in: guardInput.selectedRange))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("-60", in: guardInput.selectedRange))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("-14", in: guardInput.selectedRange))
        guardInput.select(.atLeast, first: 0)
        XCTAssertTrue(MoveFrameRangeMatcher.matches("+45", in: guardInput.selectedRange))
    }

    func test_manual_range_has_inclusive_endpoints_without_clamping() {
        var input = FrameFilterInput(allowsNegative: false)
        input.select(.range, first: 45, second: 60)
        XCTAssertEqual(input.selectedRange, 45...60)
        XCTAssertTrue(MoveFrameRangeMatcher.matches("45", in: input.selectedRange))
        XCTAssertTrue(MoveFrameRangeMatcher.matches("60", in: input.selectedRange))
        XCTAssertFalse(MoveFrameRangeMatcher.matches("61", in: input.selectedRange))
    }

    func test_invalid_input_never_creates_a_range_or_enables_apply() {
        for text in ["", "-", "+", "15.5", "abc", "999999999999999999999999999"] {
            var state = FilterState()
            state.startup.mode = .exact
            state.startup.firstText = text
            XCTAssertFalse(state.isValid, text)
            XCTAssertNil(state.startup.selectedRange, text)
        }
        var input = FrameFilterInput(allowsNegative: false)
        input.select(.range, first: 20, second: 10)
        XCTAssertNotNil(input.validationMessage)
        XCTAssertNil(input.selectedRange)
        input.select(.exact, first: -1)
        XCTAssertNotNil(input.validationMessage)
        input.select(.range, first: 0, second: -1)
        XCTAssertNotNil(input.validationMessage)
    }

    func test_signed_guard_input_supports_paste_and_sign_toggle() {
        var input = FrameFilterInput(allowsNegative: true)
        input.mode = .exact
        input.firstText = " +5 "
        XCTAssertEqual(input.selectedRange, 5...5)
        input.firstText = "−15"
        XCTAssertEqual(input.selectedRange, -15...(-15))
        XCTAssertEqual(FrameFilterInput.togglingSign(of: "-15"), "15")
        XCTAssertEqual(FrameFilterInput.togglingSign(of: "+15"), "-15")
        XCTAssertEqual(FrameFilterInput.togglingSign(of: ""), "-")
    }

    func test_reopening_preserves_exact_one_sided_and_custom_ranges() {
        for range in [15...15, 21...Int.max, Int.min...(-15), -60...45, 45...60] {
            let input = FrameFilterInput(selectedRange: range, allowsNegative: true)
            XCTAssertEqual(input.selectedRange, range)
            XCTAssertNil(input.validationMessage)
        }
        XCTAssertEqual(FrameFilterInput(selectedRange: 15...15, allowsNegative: false).mode, .exact)
        XCTAssertEqual(FrameFilterInput(selectedRange: 21...Int.max, allowsNegative: false).mode, .atLeast)
        XCTAssertEqual(FrameFilterInput(selectedRange: Int.min...(-15), allowsNegative: true).mode, .atMost)
    }

    func test_any_and_reset_clear_frame_conditions_and_active_count() {
        var state = FilterState()
        state.startup.select(.exact, first: 15)
        state.guardFrame.select(.atMost, first: -10)
        XCTAssertEqual(state.activeCount, 2)
        state.startup.mode = .any
        state.startup.firstText = "invalid draft"
        XCTAssertNil(state.startup.selectedRange)
        XCTAssertTrue(state.isValid)
        XCTAssertEqual(state.activeCount, 1)
        state.reset()
        XCTAssertEqual(state.activeCount, 0)
        XCTAssertNil(state.startup.selectedRange)
        XCTAssertNil(state.guardFrame.selectedRange)
    }
}
