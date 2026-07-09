//
//  MemoBackupTests.swift
//  TK8Tests
//

@testable import TK8
import XCTest

final class MemoBackupCodecTests: XCTestCase {
    func test_encode_decode_roundTrip_preservesMemoFields() throws {
        let sut = MemoBackupCodec()
        let memo = Memo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            characterName: "Jin",
            title: "Wall combo",
            body: "Keep original memo body",
            isPinned: true,
            updatedAt: Date(timeIntervalSince1970: 1_725_000_000)
        )

        let data = try sut.encode(
            memos: [memo],
            exportedAt: Date(timeIntervalSince1970: 1_725_000_100)
        )
        let decoded = try sut.decodeMemos(from: data)

        XCTAssertEqual(decoded, [memo])
    }

    func test_fileName_usesAppSpecificExtension() {
        let fileName = MemoBackupDocument.fileName(exportedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(fileName, "tekken8-memos-19700101-000000.tk8memos")
    }

    func test_decode_지원하지_않는_formatVersion이면_에러를_던짐() {
        let sut = MemoBackupCodec()
        let json = #"{"formatVersion":99,"exportedAt":"2024-01-01T00:00:00Z","memos":[]}"#

        XCTAssertThrowsError(try sut.decodeMemos(from: Data(json.utf8))) { error in
            guard case MemoBackupError.unsupportedFormatVersion(99) = error else {
                XCTFail("Expected unsupportedFormatVersion error, got \(error)")
                return
            }
        }
    }

    func test_decode_잘못된_JSON이면_decodingError를_던짐() {
        let sut = MemoBackupCodec()

        XCTAssertThrowsError(try sut.decodeMemos(from: Data("not json".utf8))) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
}

extension MemoRepositoryTests {
    func test_upsert_없는_id는_새_메모로_추가함() throws {
        let memo = Memo(
            id: UUID(),
            characterName: "Jin",
            title: "백업 메모",
            body: "복원된 메모",
            isPinned: true,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        let result = try sut.upsert(memos: [memo])
        let fetched = try sut.fetchMemos()

        XCTAssertEqual(result, MemoImportResult(insertedCount: 1, updatedCount: 0, skippedCount: 0))
        XCTAssertEqual(fetched, [memo])
    }

    func test_upsert_빈_배열이면_모든_카운트가_0임() throws {
        let result = try sut.upsert(memos: [])
        let fetched = try sut.fetchMemos()

        XCTAssertEqual(result, MemoImportResult(insertedCount: 0, updatedCount: 0, skippedCount: 0))
        XCTAssertEqual(fetched, [])
    }

    func test_upsert_같은_id가_있고_import가_더_최신이면_업데이트함() throws {
        let id = UUID()
        let local = Memo(
            id: id,
            characterName: "Jin",
            title: "기존 메모",
            body: "오래된 내용",
            isPinned: false,
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        let imported = Memo(
            id: id,
            characterName: "Jin",
            title: "가져온 메모",
            body: "새 내용",
            isPinned: true,
            updatedAt: Date(timeIntervalSince1970: 200)
        )

        _ = try sut.upsert(memos: [local])
        let result = try sut.upsert(memos: [imported])
        let fetched = try sut.fetchMemos()

        XCTAssertEqual(result, MemoImportResult(insertedCount: 0, updatedCount: 1, skippedCount: 0))
        XCTAssertEqual(fetched, [imported])
    }

    func test_upsert_같은_id가_있고_import가_더_오래됐으면_유지함() throws {
        let id = UUID()
        let local = Memo(
            id: id,
            characterName: "Jin",
            title: "기존 메모",
            body: "최신 내용",
            isPinned: true,
            updatedAt: Date(timeIntervalSince1970: 200)
        )
        let imported = Memo(
            id: id,
            characterName: "Jin",
            title: "가져온 메모",
            body: "오래된 내용",
            isPinned: false,
            updatedAt: Date(timeIntervalSince1970: 100)
        )

        _ = try sut.upsert(memos: [local])
        let result = try sut.upsert(memos: [imported])
        let fetched = try sut.fetchMemos()

        XCTAssertEqual(result, MemoImportResult(insertedCount: 0, updatedCount: 0, skippedCount: 1))
        XCTAssertEqual(fetched, [local])
    }

    func test_upsert_같은_id와_updatedAt이면_기존_메모를_유지함() throws {
        let id = UUID()
        let updatedAt = Date(timeIntervalSince1970: 100)
        let local = Memo(
            id: id,
            characterName: "Jin",
            title: "기존 메모",
            body: "기존 내용",
            isPinned: false,
            updatedAt: updatedAt
        )
        let imported = Memo(
            id: id,
            characterName: "Jin",
            title: "가져온 메모",
            body: "가져온 내용",
            isPinned: true,
            updatedAt: updatedAt
        )

        _ = try sut.upsert(memos: [local])
        let result = try sut.upsert(memos: [imported])
        let fetched = try sut.fetchMemos()

        XCTAssertEqual(result, MemoImportResult(insertedCount: 0, updatedCount: 0, skippedCount: 1))
        XCTAssertEqual(fetched, [local])
    }
}
