//
//  String+CommandParsing.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/29/25.
//

import Foundation

extension String {
    func tokenizeCommands() -> [String] {
        // 1) commands 리스트 (길이 내림차순)
        let pre = self
                    .replacingOccurrences(of: "(", with: " ( ")
                    .replacingOccurrences(of: ")", with: " ) ")
                    .replacingOccurrences(of: "[", with: " [ ")
                    .replacingOccurrences(of: "]", with: " ] ")
        
        let commands = GlobalConstants.commands.sorted { $0.count > $1.count }
        
        // 2) “순수 커맨드 단어”만 그리디 분할해 주는 함수
        func segmentPureCommands(_ word: String) -> [String]? {
            var tokens: [String] = []
            var idx = word.startIndex
            
            while idx < word.endIndex {
                // 길이가 긴 것부터 시도
                var matched: String? = nil
                for cmd in commands {
                    if word[idx...].hasPrefix(cmd) {
                        matched = cmd
                        break
                    }
                }
                guard let cmd = matched else {
                    // 어느 명령도 매칭되지 않으면 실패
                    return nil
                }
                tokens.append(cmd)
                idx = word.index(idx, offsetBy: cmd.count)
            }
            return tokens
        }
        
        // 3) 공백·개행 단위로 먼저 단어 분리
        let rawWords = pre
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var result: [String] = []
        var textBuffer = ""
        
        // 4) 단어 단위로 순회
        for w in rawWords {
            if let cmdTokens = segmentPureCommands(w) {
                // (A) 지금까지 모은 일반 텍스트가 있으면 flush
                if !textBuffer.isEmpty {
                    result.append(textBuffer)
                    textBuffer = ""
                }
                // (B) 커맨드 토큰들을 결과에 추가
                result.append(contentsOf: cmdTokens)
            } else {
                // 일반 단어는 버퍼에 붙이기 (띄어쓰기 포함)
                if textBuffer.isEmpty {
                    textBuffer = w
                } else {
                    textBuffer += " " + w
                }
            }
        }
        // 마지막 텍스트 남아있으면 추가
        if !textBuffer.isEmpty {
            result.append(textBuffer)
        }
        
        return result
    }
}
