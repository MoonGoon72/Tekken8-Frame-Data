// TranslatorEngine.swift
import Foundation

private final class Box<T> {
    let value: T

    init(value: T) { self.value = value }
}

final class TranslatorEngine {
    enum Lang: String, Sendable { case ko, en }

    private var cache = NSCache<NSString, Box<LocalizedMove>>()

    func localize(move: Move, to lang: Lang) -> LocalizedMove {
        // ko: 원형
        if lang == .ko {
            return LocalizedMove(
                id: move.id,
                sortOrder: move.sortOrder,
                section: move.section,
                skillNamePrimary: move.skillNameKR ?? move.skillNameEN ?? "",
                skillNameSecondary: move.skillNameEN,
                command: move.command ?? "",
                commandEN: nil, // ko에선 굳이 안 써도 됨
                judgment: JudgmentTranslator.localize(move.judgment, to: .ko),
                damage: move.damage,
                startupFrame: move.startupFrame,
                guardFrame: move.guardFrame,
                hitFrame: move.hitFrame,
                counterFrame: move.counterFrame,
                attribute: move.attribute,
                description: move.description
            )
        }

        let key = NSString(string: "\(move.id)|\(move.command ?? "")|\(move.description ?? "")|\(move.section)|\(move.skillNameEN ?? "")|\(move.skillNameKR ?? "")")
        if let hit = cache.object(forKey: key) { return hit.value }

        // TranslatorEngine.localize(_:to:)
        let commandRaw = move.command ?? ""
        // (A) 화면 표시용 커맨드: 문장만 EN, 커맨드 토큰은 보존
        let commandDisplay = KRToENDescription.translatePreservingCommands(commandRaw)
        // (B) 검색 보조용 서양식
        let commandEN = ENCommandRenderer.render(from: commandRaw)

        // 설명/섹션: 문장만 EN (커맨드는 그대로)
        let descEN = move.description.map { KRToENDescription.translatePreservingCommands($0) }
        let sectionEN = KRToENTranslator.translate(move.section) // 섹션은 보통 문장/라벨이므로 그대로 변환

        let localized = LocalizedMove(
            id: move.id,
            sortOrder: move.sortOrder,
            section: sectionEN,
            skillNamePrimary: move.skillNameEN ?? move.skillNameKR ?? "",
            skillNameSecondary: move.skillNameKR,
            command: commandDisplay,          // ⬅️ 동양식 유지
            commandEN: commandEN,        // ⬅️ 검색용 보조
            judgment: JudgmentTranslator.localize(move.judgment, to: .en),
            damage: move.damage,
            startupFrame: move.startupFrame,
            guardFrame: move.guardFrame,
            hitFrame: move.hitFrame,
            counterFrame: move.counterFrame,
            attribute: move.attribute,
            description: descEN
        )
        cache.setObject(Box<LocalizedMove>(value: localized), forKey: key)
        return localized
    }
}

enum JudgmentTranslator {
    private static let tokenMap = [
        "상": "high",
        "중": "mid",
        "하": "low",
        "특중": "s.mid",
        "특하": "s.low",
        "상단가불": "high unblockable",
        "중단가불": "mid unblockable",
        "가불": "unblockable",
    ]

    private static let koreanTokens = tokenMap.keys.sorted { $0.count > $1.count }

    static func localize(_ judgment: String?, to lang: TranslatorEngine.Lang) -> String? {
        guard let judgment else { return nil }
        guard lang == .en else { return judgment }

        let tokens = tokenize(judgment)
        guard !tokens.isEmpty else { return judgment }
        return tokens.map { tokenMap[$0] ?? $0 }.joined(separator: " ")
    }

    private static func tokenize(_ judgment: String) -> [String] {
        let trimmed = judgment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let separators = CharacterSet(charactersIn: ",/|·・ㆍ").union(.whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }
        if parts.count > 1 {
            return parts.flatMap(tokenizeSinglePart)
        }

        return tokenizeSinglePart(trimmed)
    }

    private static func tokenizeSinglePart(_ part: String) -> [String] {
        if tokenMap[part] != nil { return [part] }

        var remaining = part
        var tokens: [String] = []

        while !remaining.isEmpty {
            guard let token = koreanTokens.first(where: { remaining.hasPrefix($0) }) else {
                remaining.removeFirst()
                continue
            }

            tokens.append(token)
            remaining.removeFirst(token.count)
        }

        return tokens
    }
}
