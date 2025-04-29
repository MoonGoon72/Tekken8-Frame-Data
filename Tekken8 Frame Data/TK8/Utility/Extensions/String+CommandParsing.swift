//
//  String+CommandParsing.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/29/25.
//

import Foundation

extension String {
    func tokenizeCommands() -> [String] {
        let sorted = GlobalConstants.commands.sorted { $0.count > $1.count }
        
        /// 2. 정규식 패턴 생성 (메타문자 이스케이프 주의)
        let escaped = sorted
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        let pattern = "(\(escaped))"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        
        /// 3. 토큰화
        let ns = self as NSString
        let fullRange = NSRange(location:0, length: ns.length)
        let matches = regex.matches(in: self, range: fullRange)
        
        var tokens: [String] = []
        var lastEnd = 0
        
        for m in matches {
            let commandRange = m.range(at: 1)
            // 3-1. 매치 전의 "일반 텍스트" 추출
            if commandRange.location > lastEnd {
                let text = ns.substring(with: NSRange(location: lastEnd, length: commandRange.location - lastEnd))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { tokens.append(text) }
            }
            
            // 3-2. 매치된 커맨드
            let command = ns.substring(with: commandRange)
            tokens.append(command)
            
            lastEnd = commandRange.location + commandRange.length
        }
        // 3-3. 마지막 일반 텍스트
        if lastEnd < ns.length {
            let tail = ns.substring(from: lastEnd).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { tokens.append(tail) }
        }
        
        // --- 여기서부터 후처리: 'n' 토큰 처리 ---
        var finalTokens: [String] = []
        for token in tokens {
            if token == "n" {
                // 직전 토큰이 commands 에 있는 경우에만 'n' 분리
                if let prev = finalTokens.last, GlobalConstants.commands.contains(prev) {
                    finalTokens.append("n")
                } else {
                    // 그렇지 않으면, 직전 텍스트에 붙여버리기
                    if let last = finalTokens.popLast() {
                        finalTokens.append(last + "n")
                    } else {
                        finalTokens.append("n")
                    }
                }
            } else {
                finalTokens.append(token)
            }
        }
        return finalTokens
    }
}
