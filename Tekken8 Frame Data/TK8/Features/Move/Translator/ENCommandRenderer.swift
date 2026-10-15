//
//  ENCommandRenderer.swift
//  TK8
//

import Foundation

enum ENCommandRenderer {
    // 퍼블릭: 원본 문자열 → EN 표기 문자열
    static func render(from raw: String) -> String {
        let tokens = raw.tokenizeCommands()                      // 네가 가진 토크나이저
        let mapped = tokens.flatMap(mapTokenToENAtomicTokens)    // 개별 토큰 EN화(방향/버튼/텍스트)
        let collapsed = collapseMotions(in: mapped)              // qcf/dp 등 축약
        return collapsed.joined()
    }

    // MARK: - 1) 토큰 매핑 (JP/KR → EN 원자 토큰)
    // 반환을 [String]으로 둔 이유: 하나의 입력 토큰이 여러 EN 토큰으로 확장될 수 있음(예: "ap" -> ["1","+","2"])
    private static func mapTokenToENAtomicTokens(_ token: String) -> [String] {
        // 괄호/브라켓/콤마, 기타 텍스트: 그대로 유지
        if token == "(" || token == ")" || token == "[" || token == "]" { return [token] }
        if token == "," || token == "~" || token == ":" || token == "<" || token == ">" || token == "*" || token == "#" { return [token] }

        // 1) 유지 입력(hold) 방향(예: "1_" -> "DB")
        if token.hasSuffix("_") {
            let core = String(token.dropLast()) // "1"
            if let dir = mapDigitDirection(core, hold: true) { return [dir] }
            // 버튼 hold 같은 특수 케이스가 생기면 여기서 처리
        }

        // 2) 단일 방향(숫자) or n
        if let dir = mapDigitDirection(token, hold: false) { return [dir] }

        // 3) 버튼/버튼 조합
        if token.contains("+") {
            // 예: "ap+lk", "lp+rk"
            let parts = token.split(separator: "+").map(String.init)
            let mapped = parts.flatMap(mapSingleButtonToNumbers)
            // 버튼들 사이에 '+' 삽입
            return interleave(mapped, with: "+")
        } else {
            // 단일 버튼 or 기타 텍스트
            let mapped = mapSingleButtonToNumbers(token)
            if !mapped.isEmpty { return mapped } // 이미 숫자+로 확장된 상태(여러 조각)
        }

        // 4) 그 외 텍스트는 그대로(예: "WR.", "CD.", "DES.", "lp rk" 같은 raw text)
        return [token]
    }

    // 숫자 방향 매핑
    private static func mapDigitDirection(_ s: String, hold: Bool) -> String? {
        let map: [String: String] = [
            "1":"db","2":"d","3":"df","4":"b","n":"n","6":"f","7":"ub","8":"u","9":"uf"
        ]
        guard let base = map[s] else { return nil }
        if hold {
            return base.uppercased() // DB, D, DF, ...
        }
        return base
    }

    // 단일 버튼을 숫자(철권식)로 매핑. 결과는 ["1","+","2"]처럼 여러 조각일 수 있음
    private static func mapSingleButtonToNumbers(_ s: String) -> [String] {
        switch s.lowercased() {
        case "lp": return ["1"]
        case "rp": return ["2"]
        case "lk": return ["3"]
        case "rk": return ["4"]
        case "ap": return ["1","+","2"]
        case "ak": return ["3","+","4"]
        case "al": return ["1","+","3"]
        case "ar": return ["2","+","4"]
        case "all": return ["1","+","2","+","3","+","4"]
        default:   return [] // 버튼이 아니면 빈 배열
        }
    }

    // ["1","2","3"] + "+" 삽입 유틸
    private static func interleave(_ array: [String], with sep: String) -> [String] {
        guard !array.isEmpty else { return [] }
        var out: [String] = []
        for (i, a) in array.enumerated() {
            out.append(a)
            if i < array.count - 1 { out.append(sep) }
        }
        return out
    }

    // MARK: - 2) 모션 축약 (qcf/dp/…)
    // 입력은 이미 EN 방향 토큰으로 변환된 상태여야 함.
    private static func collapseMotions(in tokens: [String]) -> [String] {
        // 축약 대상이 아닌 토큰(버튼 숫자/+, 괄호/텍스트)은 그대로 흘려보내고,
        // 방향 토큰들만 패턴 매칭으로 qcf 등으로 바꿔 끼운다.
        var out: [String] = []
        var i = 0
        while i < tokens.count {
            // 방향 시퀀스 인덱스 매치용
            func isDir(_ idx: Int, _ val: String) -> Bool {
                guard idx < tokens.count else { return false }
                return tokens[idx] == val
            }

            // helper: 특정 패턴 모두 방향인지 확인
            func match(_ start: Int, _ pattern: [String]) -> Bool {
                guard start + pattern.count <= tokens.count else { return false }
                for k in 0..<pattern.count {
                    if tokens[start+k] != pattern[k] { return false }
                }
                return true
            }

            // qcf: d,df,f
            if match(i, ["d","df","f"]) {
                out.append("qcf"); i += 3; continue
            }
            // qcb: d,db,b
            if match(i, ["d","db","b"]) {
                out.append("qcb"); i += 3; continue
            }
            // hcf: b,db,d,df,f
            if match(i, ["b","db","d","df","f"]) {
                out.append("hcf"); i += 5; continue
            }
            // hcb: f,df,d,db,b
            if match(i, ["f","df","d","db","b"]) {
                out.append("hcb"); i += 5; continue
            }
            // dp: f,d,df
            if match(i, ["f","d","df"]) {
                out.append("dp"); i += 3; continue
            }

            // 위 패턴 외에는 그대로 통과
            out.append(tokens[i]); i += 1
        }
        return out
    }
}
