//
//  KRToENDescription.swift
//  TK8
//

import Foundation

enum KRToENDescription {
    private static let commandPattern: NSRegularExpression = {
        let tokens = GlobalConstants.commands.sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
        return try! NSRegularExpression(
            pattern: #"(?<![\p{L}\p{N}_+])(?>\#(tokens))+(?:\+(?>\#(tokens))+)*(?![A-Za-z0-9_+])(?=[^가-힣]|(?:을|를|로)(?![가-힣])|$)"#
        )
    }()

    /// description 전체를 번역하되, 커맨드 토큰은 그대로 보존한다.
    /// 파이프("| ")로 분할된 각 줄을 독립적으로 처리.
    static func translatePreservingCommands(_ description: String) -> String {
        return description
            .components(separatedBy: "| ")
            .map { translateLineMaskingCommands($0) }
            .joined(separator: " | ")
    }

    private static func translateLineMaskingCommands(_ line: String) -> String {
        // Mask complete inputs, including commands followed by a Korean particle.
        // Reuse the command alphabet used by the UI and search renderer.
        let input = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = input as NSString
        let commandMatches = commandPattern.matches(in: input, range: NSRange(location: 0, length: source.length))
        var masked = source
        for (index, match) in commandMatches.enumerated().reversed() {
            masked = masked.replacingCharacters(in: match.range, with: "__CMD\(index)__") as NSString
        }

        var translated = KRToENTranslator.translate(masked as String)

        translated = translated.replacingOccurrences(of: #"(__CMD\d+__)\s*\("#, with: "$1 (", options: .regularExpression)

        // 4.5) 괄호 안 텍스트도 동일 파이프라인으로 번역 (단일 패스, 뒤에서부터 치환)
        let parenRx = try! NSRegularExpression(pattern: #"\(([^)]*)\)"#)
        let matches = parenRx.matches(in: translated, range: NSRange(translated.startIndex..., in: translated))
        if !matches.isEmpty {
            var newText = translated as NSString
            // 뒤에서부터 치환해야 인덱스가 안 틀어짐
            for m in matches.reversed() {
                let inner = newText.substring(with: m.range(at: 1))
                let innerEN = translateLineMaskingCommands(inner)
                    .replacingOccurrences(of: #"^Or\b"#, with: "or", options: .regularExpression)
                newText = newText.replacingCharacters(in: m.range, with: "(\(innerEN))") as NSString
            }
            translated = newText as String
        }
        
        // 5) 플레이스홀더를 원래 커맨드로 복원
        for (index, match) in commandMatches.enumerated() {
            let command = source.substring(with: match.range)
            translated = translated.replacingOccurrences(of: "__CMD\(index)__", with: command)
        }

        translated = translated.replacingOccurrences(
            of: #"(on hit or block|on ground hit|on hit|on block|cannot block)\("#, with: "$1 (", options: .regularExpression
        )

        // 6) 공백 정리
        translated = translated
            .replacingOccurrences(of: #"\(\s+"#, with: "(", options: .regularExpression)
            .replacingOccurrences(of: #"\s+\)"#, with: ")", options: .regularExpression)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return translated
    }
}
