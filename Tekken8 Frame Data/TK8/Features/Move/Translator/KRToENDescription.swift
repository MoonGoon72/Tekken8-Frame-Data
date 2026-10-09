//
//  KRToENDescription.swift
//  TK8
//

import Foundation

enum KRToENDescription {
    /// description 전체를 번역하되, 커맨드 토큰은 그대로 보존한다.
    /// 파이프("| ")로 분할된 각 줄을 독립적으로 처리.
    static func translatePreservingCommands(_ description: String) -> String {
        return description
            .components(separatedBy: "| ")
            .map { translateLineMaskingCommands($0) }
            .joined(separator: " | ")
    }

    private static func translateLineMaskingCommands(_ line: String) -> String {
        // 1) 토큰화
        let tokens = line.tokenizeCommands()

        // 2) 커맨드 판정: GlobalConstants + 버튼 콤보(lk+rp 등) 정규식
        let cmdSet = Set(GlobalConstants.commands)
        let comboRegex = try! NSRegularExpression(
            pattern: #"(?:lp|rp|lk|rk|ap|ak|al|ar|all)(?:\+(?:lp|rp|lk|rk|ap|ak|al|ar|all))+"#
        )
        func isCommandLike(_ t: String) -> Bool {
            if cmdSet.contains(t) { return true }
            let r = NSRange(t.startIndex..., in: t)
            return comboRegex.firstMatch(in: t, range: r) != nil
        }

        // 3) 커맨드 토큰을 플레이스홀더로 마스킹
        var maskedPieces: [String] = []
        var placeholders: [String: String] = [:]
        var cmdIndex = 0
        for t in tokens {
            if isCommandLike(t) {
                let ph = "__CMD\(cmdIndex)__"
                cmdIndex += 1
                placeholders[ph] = t
                maskedPieces.append(ph)
            } else {
                maskedPieces.append(t)
            }
        }

        // 4) 문장 단위 번역 (패턴들이 제대로 작동)
        let masked = maskedPieces.joined(separator: " ")
        var translated = KRToENTranslator.translate(masked)

        // 4.5) 괄호 안 텍스트도 동일 파이프라인으로 번역 (단일 패스, 뒤에서부터 치환)
        let parenRx = try! NSRegularExpression(pattern: #"\(([^)]*)\)"#)
        let matches = parenRx.matches(in: translated, range: NSRange(translated.startIndex..., in: translated))
        if !matches.isEmpty {
            var newText = translated as NSString
            // 뒤에서부터 치환해야 인덱스가 안 틀어짐
            for m in matches.reversed() {
                let inner = newText.substring(with: m.range(at: 1))
                let innerEN = translateLineMaskingCommands(inner) // 커맨드 보존 규칙 그대로 적용
                newText = newText.replacingCharacters(in: m.range, with: "(\(innerEN))") as NSString
            }
            translated = newText as String
        }
        
        // 5) 플레이스홀더를 원래 커맨드로 복원
        for (ph, original) in placeholders {
            translated = translated.replacingOccurrences(of: ph, with: original)
        }

        // 6) 공백 정리
        translated = translated
            .replacingOccurrences(of: #"\(\s+"#, with: "(", options: .regularExpression)
            .replacingOccurrences(of: #"\s+\)"#, with: ")", options: .regularExpression)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return translated
    }
}
