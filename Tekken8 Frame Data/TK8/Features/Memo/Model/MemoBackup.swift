//
//  MemoBackup.swift
//  TK8
//

import Foundation
import UniformTypeIdentifiers

struct MemoBackupExport {
    let data: Data
    let fileName: String
}

struct MemoImportResult: Equatable {
    let insertedCount: Int
    let updatedCount: Int
    let skippedCount: Int
}

struct MemoBackupFile: Codable, Equatable {
    let formatVersion: Int
    let exportedAt: Date
    let memos: [MemoBackupItem]

    init(formatVersion: Int = 1, exportedAt: Date = Date(), memos: [Memo]) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.memos = memos.map(MemoBackupItem.init)
    }
}

struct MemoBackupItem: Codable, Equatable {
    let id: UUID
    let characterName: String
    let title: String
    let body: String
    let isPinned: Bool
    let updatedAt: Date

    init(memo: Memo) {
        id = memo.id
        characterName = memo.characterName
        title = memo.title
        body = memo.body
        isPinned = memo.isPinned
        updatedAt = memo.updatedAt
    }

    var memo: Memo {
        Memo(
            id: id,
            characterName: characterName,
            title: title,
            body: body,
            isPinned: isPinned,
            updatedAt: updatedAt
        )
    }
}

struct MemoBackupCodec {
    func encode(memos: [Memo], exportedAt: Date = Date()) throws -> Data {
        let backup = MemoBackupFile(exportedAt: exportedAt, memos: memos)
        return try JSONEncoder.memoBackup.encode(backup)
    }

    func decodeMemos(from data: Data) throws -> [Memo] {
        let backup = try JSONDecoder.memoBackup.decode(MemoBackupFile.self, from: data)
        guard backup.formatVersion == 1 else {
            throw MemoBackupError.unsupportedFormatVersion(backup.formatVersion)
        }
        return backup.memos.map(\.memo)
    }
}

enum MemoBackupError: Error {
    case unsupportedFormatVersion(Int)
}

enum MemoBackupDocument {
    static let fileExtension = "tk8memos"
    static let contentType = UTType(exportedAs: "com.moongoon.tk8.memos", conformingTo: .json)

    static func fileName(exportedAt: Date = Date()) -> String {
        let date = MemoBackupFileNameFormatter.string(from: exportedAt)
        return "tekken8-memos-\(date).\(fileExtension)"
    }
}

private enum MemoBackupFileNameFormatter {
    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}

private extension JSONEncoder {
    static var memoBackup: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(MemoBackupDateFormatter.string(from: date))
        }
        return encoder
    }
}

private extension JSONDecoder {
    static var memoBackup: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = MemoBackupDateFormatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid date format: \(string)"
                )
            }
            return date
        }
        return decoder
    }
}

private enum MemoBackupDateFormatter {
    static func string(from date: Date) -> String {
        fractionalFormatter.string(from: date)
    }

    static func date(from string: String) -> Date? {
        fractionalFormatter.date(from: string) ?? standardFormatter.date(from: string)
    }

    private static let fractionalFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
