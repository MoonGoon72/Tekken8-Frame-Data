import XCTest
@testable import TK8

final class SharedMoveTranslationTests: XCTestCase {
    func testHeatBurstUsesSharedRulesAndKeepsSearchNotation() {
        let move = makeMove()
        let engine = TranslatorEngine()

        let result = engine.localize(move: move, to: .en)

        XCTAssertEqual(result.section, "Heat Moves")
        XCTAssertEqual(result.command, "When Heat activation available rp+lk")
        XCTAssertEqual(
            result.description,
            "Also possible during Rocket Stance | - Partially uses remaining Heat time | - rp+lk44 to cancel attack"
        )
        XCTAssertEqual(result.commandEN, ENCommandRenderer.render(from: move.command ?? ""))
        XCTAssertEqual(engine.localize(move: move, to: .ko).description, move.description)
    }

    func testStanceCommandUsesEnglishWordOrderAndKeepsCommandTokens() {
        let move = makeMove(command: "Astronauts(6al 히트 시 등) 도중 lp(혹은 rp)", description: nil)
        let result = TranslatorEngine().localize(move: move, to: .en)

        XCTAssertEqual(result.command, "During Astronauts (6al on hit, etc.) lp (or rp)")
        XCTAssertNil(result.description)
    }

    func testExistingHeatAndChipDamageRules() {
        let move = makeMove(command: "히트 상태에서 lp", description: "- 가드 데미지 있음")
        let result = TranslatorEngine().localize(move: move, to: .en)

        XCTAssertEqual(result.section, "Heat Moves")
        XCTAssertEqual(result.command, "During Heat lp")
        XCTAssertEqual(result.description, "- Chip damage on block")
    }

    func testSameRulesApplyToOtherCharactersWithDifferentStances() {
        let move = makeMove(
            characterName: "King",
            command: "Jaguar Sprint(6lk 히트 시 등) 도중 6lp+rk(혹은 2rp)",
            description: "- 지상 히트 시 Jaguar Sprint로(4_를 입력하면 이행하지 않음)"
        )
        let result = TranslatorEngine().localize(move: move, to: .en)

        XCTAssertEqual(result.section, "Heat Moves")
        XCTAssertEqual(result.command, "During Jaguar Sprint (6lk on hit, etc.) 6lp+rk (or 2rp)")
        XCTAssertEqual(result.description, "- Shift to Jaguar Sprint on ground hit (does not shift with 4_)")
        XCTAssertEqual(result.commandEN, ENCommandRenderer.render(from: move.command ?? ""))
    }

    func testSharedCommandContextsAndSections() {
        XCTAssertEqual(KRToENDescription.translatePreservingCommands("다운 상태에서 8_"), "While down 8_")
        XCTAssertEqual(KRToENDescription.translatePreservingCommands("상대의 뒤에서 접근하여 6al"), "Approach opponent from behind 6al")
        XCTAssertEqual(KRToENDescription.translatePreservingCommands("앞구르기 도중 ap"), "While rolling forward ap")
        XCTAssertEqual(KRToENDescription.translatePreservingCommands("2lk"), "2lk")
        XCTAssertEqual(KRToENTranslator.translateSection("Jaguar Sprint 도중의 기술"), "Moves during Jaguar Sprint")
        XCTAssertEqual(KRToENTranslator.translateSection("히트 시스템(King)"), "Heat System (King)")
        XCTAssertEqual(KRToENTranslator.translateSection("반격기"), "Reversal")
    }

    func testDescriptionPreservesBulletBoundariesAndDownedHitException() {
        let input = "- 가드 대미지 있음 | - 히트 혹은 가드 시 Jaguar Sprint로(다운 히트 시 혹은 6_를 입력하면 이행하지 않음)"
        XCTAssertEqual(
            KRToENDescription.translatePreservingCommands(input),
            "- Chip damage on block | - Shift to Jaguar Sprint on hit or block (does not shift when hitting a downed opponent or with 6_)"
        )
    }

    private func makeMove(
        characterName: String = "Roger Jr",
        command: String = "히트 발동 가능 상태에서 rp+lk",
        description: String? = "- Rocket Stance 도중에도 사용 가능 | - 히트 상태의 남은 시간을 소비 | - rp+lk44를 입력하면 공격을 캔슬"
    ) -> Move {
        Move(
            id: 1, sortOrder: 1, characterName: characterName, section: "히트 관련 기술",
            skillNameEN: "Heat Burst", skillNameKR: "Heat Burst", skillNickname: nil,
            command: command, judgment: "중", damage: "12", startupFrame: "16F",
            guardFrame: nil, hitFrame: nil, counterFrame: nil, attribute: nil,
            description: description
        )
    }
}
