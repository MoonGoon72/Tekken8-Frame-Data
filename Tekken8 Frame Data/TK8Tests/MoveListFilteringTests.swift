//
//  MoveListFilteringTests.swift
//  TK8Tests
//

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

    // MARK: - TODO(human): Combined Filtering Test
}
