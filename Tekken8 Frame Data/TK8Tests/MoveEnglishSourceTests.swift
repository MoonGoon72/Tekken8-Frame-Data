import CoreData
import XCTest
@testable import TK8

final class MoveEnglishSourceTests: XCTestCase {
    func testEnglishSourceTakesPriorityAndCacheTracksChanges() throws {
        var move = try decode(english: #", "command_en":"With Anathema lp", "description_en":"Can hold at last step""#)
        let engine = TranslatorEngine()
        XCTAssertEqual(engine.localize(move: move, to: .en).command, "With Anathema lp")
        XCTAssertEqual(engine.localize(move: move, to: .en).description, "Can hold at last step")
        XCTAssertEqual(engine.localize(move: move, to: .ko).description, "홀드 가능")

        move.descriptionEnglish = " "
        XCTAssertEqual(engine.localize(move: move, to: .en).description, "can hold")
        XCTAssertEqual(engine.localize(move: move, to: .en).commandEN, ENCommandRenderer.render(from: "lp"))
    }

    func testOlderResponseFallsBack() throws {
        let move = try decode(english: "")
        XCTAssertNil(move.commandEnglish)
        XCTAssertNil(move.descriptionEnglish)
        XCTAssertEqual(TranslatorEngine().localize(move: move, to: .en).description, "can hold")
    }

    func testEnglishSourceSurvivesCoreDataMapping() throws {
        let move = try decode(english: #", "command_en":"With Anathema lp", "description_en":"Can hold at last step""#)
        let container = NSPersistentContainer(name: "Tekken8FrameData")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in XCTAssertNil(error) }
        let entity = MoveDTO(domain: move).toEntity(context: container.viewContext)
        try container.viewContext.save()
        let cached = MoveDTO(entity: entity).toDomain()
        XCTAssertEqual(cached.commandEnglish, move.commandEnglish)
        XCTAssertEqual(cached.descriptionEnglish, move.descriptionEnglish)
    }

    private func decode(english: String) throws -> Move {
        let json = #"{"id":1,"sort_order":1,"character_name":"King","section":"일반","command":"lp","description":"홀드 가능""#
        return try JSONDecoder().decode(Move.self, from: Data((json + english + "}").utf8))
    }
}
