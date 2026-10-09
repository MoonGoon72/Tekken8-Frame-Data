//
//  LocalizedMove.swift
//  TK8
//

import Foundation

struct LocalizedMove: Hashable, Identifiable, Sendable {
    let id: Int64
    let sortOrder: Double
    let section: String              // 표시용 섹션(언어 반영)
    let skillNamePrimary: String      // 좌측 큰 제목 (ko면 KR, 그 외 EN)
    let skillNameSecondary: String?   // 우측 보조 제목
    let command: String               // 렌더용 커맨드(변환 완료)
    let commandEN: String?            // 서양식
    let judgment: String?
    let damage: String?
    let startupFrame: String?
    let guardFrame: String?
    let hitFrame: String?
    let counterFrame: String?
    let attribute: String?
    let description: String?
}

extension Array where Element == LocalizedMove {
    /// 전체 Move 배열에서 섹션별 원본 등장 순 리스트 생성
    /// - Parameter moves: 원본 Move 배열
    /// - Returns: 중복 제거된 섹션 이름 배열
    static func overallSectionOrder(from moves: [LocalizedMove]) -> [String] {
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
}
