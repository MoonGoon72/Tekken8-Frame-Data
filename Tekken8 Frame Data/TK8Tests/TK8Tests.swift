//
//  TK8Tests.swift
//  TK8Tests
//

import XCTest

final class TK8Tests: XCTestCase {

    // MARK: - Move Model Tests

    func test_move_decoding_from_json() {
        // Move의 CodingKeys가 snake_case ↔ camelCase 매핑을 올바르게 하는지 검증
        let json = """
        {
            "id": 1,
            "sort_order": 1,
            "character_name": "jin",
            "section": "일반",
            "skill_name_en": "Electric",
            "skill_name_kr": "일렉트릭",
            "skill_nickname": "전풍",
            "command": "6n23rp",
            "judgment": "상",
            "damage": "25",
            "startup_frame": "14",
            "guard_frame": "+5",
            "hit_frame": "A",
            "counter_frame": "A",
            "attribute": null,
            "description": null
        }
        """.data(using: .utf8)!

        let move = try? JSONDecoder().decode(Move.self, from: json)
        XCTAssertNotNil(move)
        XCTAssertEqual(move?.characterName, "jin")
        XCTAssertEqual(move?.skillNameEN, "Electric")
        XCTAssertEqual(move?.skillNameKR, "일렉트릭")
        XCTAssertEqual(move?.startupFrame, "14")
        XCTAssertEqual(move?.guardFrame, "+5")
    }

    func test_move_decoding_with_all_optional_null() {
        let json = """
        {
            "id": 99,
            "sort_order": 99,
            "character_name": "paul",
            "section": "일반",
            "skill_name_en": null,
            "skill_name_kr": null,
            "skill_nickname": null,
            "command": null,
            "judgment": null,
            "damage": null,
            "startup_frame": null,
            "guard_frame": null,
            "hit_frame": null,
            "counter_frame": null,
            "attribute": null,
            "description": null
        }
        """.data(using: .utf8)!

        let move = try? JSONDecoder().decode(Move.self, from: json)
        XCTAssertNotNil(move)
        XCTAssertEqual(move?.id, 99)
        XCTAssertEqual(move?.characterName, "paul")
        XCTAssertNil(move?.skillNameEN)
        XCTAssertNil(move?.command)
    }

    func test_move_hashable_conformance() {
        let move1 = Move(id: 1, sortOrder: 1, characterName: "jin", section: "일반", skillNameEN: "A", skillNameKR: "가", skillNickname: nil, command: "lp", judgment: nil, damage: nil, startupFrame: nil, guardFrame: nil, hitFrame: nil, counterFrame: nil, attribute: nil, description: nil)
        let move2 = Move(id: 1, sortOrder: 1, characterName: "jin", section: "일반", skillNameEN: "A", skillNameKR: "가", skillNickname: nil, command: "lp", judgment: nil, damage: nil, startupFrame: nil, guardFrame: nil, hitFrame: nil, counterFrame: nil, attribute: nil, description: nil)

        XCTAssertEqual(move1, move2)

        var set = Set<Move>()
        set.insert(move1)
        set.insert(move2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - LocalizedMove Tests

    func test_localizedMove_identifiable_by_id() {
        let lm1 = LocalizedMove(id: 1, sortOrder: 1, section: "일반", skillNamePrimary: "초풍", skillNameSecondary: nil, command: "6n23rp", commandEN: "f,n,d,df+2", judgment: "상", damage: "24", startupFrame: "11", guardFrame: "+5", hitFrame: "A", counterFrame: "A", attribute: nil, description: nil)
        let lm2 = LocalizedMove(id: 2, sortOrder: 2,section: "일반", skillNamePrimary: "나락 권", skillNameSecondary: nil, command: "6n23lp", commandEN: "f,n,d,df+1", judgment: "중", damage: "32", startupFrame: "20", guardFrame: "-14", hitFrame: "A", counterFrame: "A", attribute: nil, description: nil)

        XCTAssertNotEqual(lm1.id, lm2.id)
    }
}
