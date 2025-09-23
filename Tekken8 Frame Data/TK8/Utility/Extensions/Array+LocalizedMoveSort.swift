//
//  Array+LocalizedMoveSort.swift
//  TK8
//

import Foundation

extension Array where Element == LocalizedMove {
    func sortedByLocalizedRule(
        baseSectionOrder: [String] = ["히트","레이지","일반","앉은자세"], // ko 기준. en은 뷰모델에서 교체
        overallSectionOrder: [String]
    ) -> [LocalizedMove] {
        let buttonOrder = ["lp","rp","lk","rk","ap","ak","1","2","3","4","6","7","8","9"]

        func sectionPriority(_ sec: String?) -> (Int, Int) {
            let s = sec ?? ""
            if let i = baseSectionOrder.firstIndex(of: s) { return (0, i) }
            if let j = overallSectionOrder.firstIndex(of: s) { return (1, j) }
            return (1, .max)
        }

        return sorted { a, b in
            let ls = sectionPriority(a.section)
            let rs = sectionPriority(b.section)
            if ls != rs {
                if ls.0 != rs.0 { return ls.0 < rs.0 }
                return ls.1 < rs.1
            }

            let lTokens = a.command.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let rTokens = b.command.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let maxCount = Swift.max(lTokens.count, rTokens.count)
            for i in 0..<maxCount {
                if i >= lTokens.count { return true }
                if i >= rTokens.count { return false }
                let l = String(lTokens[i]), r = String(rTokens[i])
                if l != r {
                    if let li = buttonOrder.firstIndex(of: l), let ri = buttonOrder.firstIndex(of: r) {
                        return li < ri
                    }
                    if buttonOrder.contains(l) { return true }
                    if buttonOrder.contains(r) { return false }
                    if let ln = Int(l), let rn = Int(r) { return ln < rn }
                    return l < r
                }
            }
            return false
        }
    }
}
