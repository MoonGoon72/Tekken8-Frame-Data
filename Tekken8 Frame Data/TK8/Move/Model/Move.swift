//
//  Move.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/5/25.
//

import Foundation

struct Move: Decodable, Hashable {
    let id: Int64
    let characterName: String
    let section: String
    let skillNameEN: String?
    let skillNameKR: String?
    let skillNickname: String?
    let command: String?
    let judgment: String?
    let damage: String?
    let startupFrame: String?
    let guardFrame: String?
    let hitFrame: String?
    let counterFrame: String?
    let attribute: String?
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case characterName = "character_name"
        case section = "section"
        case skillNameEN = "skill_name_en"
        case skillNameKR = "skill_name_kr"
        case skillNickname = "skill_nickname"
        case command = "command"
        case judgment = "judgment"
        case damage = "damage"
        case startupFrame = "startup_frame"
        case guardFrame = "guard_frame"
        case hitFrame = "hit_frame"
        case counterFrame = "counter_frame"
        case attribute
        case description
    }
}

extension Array where Element == Move {
    /// 전체 Move 배열에서 섹션별 원본 등장 순 리스트 생성
    /// - Parameter moves: 원본 Move 배열
    /// - Returns: 중복 제거된 섹션 이름 배열
    static func overallSectionOrder(from moves: [Move]) -> [String] {
        var seen = Set<String>()
        var order = [String]()
        for move in moves {
            let sec = move.section
            if !seen.contains(sec) {
                seen.insert(sec)
                order.append(sec)
            }
        }
        return order
    }

    /// Move 배열을 섹션(base → 고유) 및 커맨드 규칙(lp, rp, ..., 숫자, 사전 순)으로 정렬
    /// - Parameters:
    ///   - baseSectionOrder: 우선 순위로 배치할 베이스 섹션 배열 (기본: ["히트", "레이지", "일반", "앉은자세"])
    ///   - overallSectionOrder: 고유 섹션을 원본 등장 순서로 정렬한 배열
    /// - Returns: 정렬된 Move 배열
    func sortedByCommandRule(
        baseSectionOrder: [String] = ["히트", "레이지", "일반", "앉은자세"],
        overallSectionOrder: [String]
    ) -> [Move] {
        let buttonOrder = ["lp", "rp", "lk", "rk", "ap", "ak", "1", "2", "3", "4", "6", "7", "8", "9"]
        
        // 섹션 우선순위 계산
        func sectionPriority(_ sec: String) -> (priority: Int, index: Int) {
            if let i = baseSectionOrder.firstIndex(of: sec) {
                return (0, i)
            }
            if let j = overallSectionOrder.firstIndex(of: sec) {
                return (1, j)
            }
            return (1, Int.max)
        }
        
        return sorted { lhs, rhs in
            // 1) Section 비교
            let ls = sectionPriority(lhs.section)
            let rs = sectionPriority(rhs.section)
            if ls != rs {
                if ls.priority != rs.priority {
                    return ls.priority < rs.priority
                }
                return ls.index < rs.index
            }
            
            // 2) Command 토큰 분리 및 비교
            let lhsTokens = lhs.command?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let rhsTokens = rhs.command?
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) } ?? []
            let maxCount = Swift.max(lhsTokens.count, rhsTokens.count)
            for i in 0..<maxCount {
                if i >= lhsTokens.count { return true }
                if i >= rhsTokens.count { return false }
                let l = String(lhsTokens[i]), r = String(rhsTokens[i])
                if l != r {
                    // 버튼 순서 우선
                    if let li = buttonOrder.firstIndex(of: l), let ri = buttonOrder.firstIndex(of: r) {
                        return li < ri
                    }
                    if buttonOrder.contains(l) { return true }
                    if buttonOrder.contains(r) { return false }
                    // 숫자 비교
                    if let ln = Int(l), let rn = Int(r) {
                        return ln < rn
                    }
                    // 그 외 문자열 사전 순
                    return l < r
                }
            }
            return false
        }
    }
}
