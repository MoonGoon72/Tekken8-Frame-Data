// TranslatorEngine.swift
import Foundation

actor TranslatorEngine {
    enum Lang: String, Sendable { case ko, en }

    private var cache: [String: LocalizedMove] = [:]
    private let rulesVersion = 1 // 변경했으니 버전 올려 캐시 무효화

    func localize(move: Move, to lang: Lang) -> LocalizedMove {
        // ko: 원형
        if lang == .ko {
            return LocalizedMove(
                id: move.id,
                section: move.section,
                skillNamePrimary: move.skillNameKR ?? move.skillNameEN ?? "",
                skillNameSecondary: move.skillNameEN,
                command: move.command ?? "",
                commandEN: nil, // ko에선 굳이 안 써도 됨
                judgment: move.judgment,
                damage: move.damage,
                startupFrame: move.startupFrame,
                guardFrame: move.guardFrame,
                hitFrame: move.hitFrame,
                counterFrame: move.counterFrame,
                attribute: move.attribute,
                description: move.description
            )
        }

        let key = "\(rulesVersion)|\(move.id)|\(move.command ?? "")|\(move.description ?? "")|\(move.section)|\(move.skillNameEN ?? "")|\(move.skillNameKR ?? "")"
        if let hit = cache[key] { return hit }

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
            section: sectionEN,
            skillNamePrimary: move.skillNameEN ?? move.skillNameKR ?? "",
            skillNameSecondary: move.skillNameKR,
            command: commandDisplay,          // ⬅️ 동양식 유지
            commandEN: commandEN,        // ⬅️ 검색용 보조
            judgment: move.judgment,
            damage: move.damage,
            startupFrame: move.startupFrame,
            guardFrame: move.guardFrame,
            hitFrame: move.hitFrame,
            counterFrame: move.counterFrame,
            attribute: move.attribute,
            description: descEN
        )
        cache[key] = localized
        return localized
    }
}
