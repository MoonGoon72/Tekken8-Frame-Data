//
//  MoveListViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Foundation

@MainActor
final class MoveListViewModel {
    @Published private(set) var filtered: [LocalizedMove] = []
    
    private(set) var moves: [Move] = []
    private var localized: [LocalizedMove] = []
    private var overallSectionsKR: [String] = [] // 원본 섹션 등장 순 (ko 기준)
    
    private let repository: MoveRepository
    private let translator = TranslatorEngine()
    
    private var lang: TranslatorEngine.Lang = (Bundle.main.preferredLocalizations.first == "ko" ? .ko : .en)
    private var preferredSections: [String] {
        switch lang {
        case .ko:
            return ["히트", "레이지", "일반", "앉은자세", "앉은 상태"]
        case .en:
            return ["Heat", "Rage", "General", "While crouching"]
        }
    }
    
    init(moveRepository repository: MoveRepository) {
        self.repository = repository
    }
    
    func setLanguage(code: String?) {
        let newLang: TranslatorEngine.Lang = (code?.hasPrefix("ko") == true) ? .ko : .en
        guard newLang != lang else { return }
        lang = newLang
        Task { await relocalizeAndSort() }
    }
    
    func fetchMoves(characterName name: String) {
        Task {
            do {
                let fetchedMoves: [Move] = try await repository.fetchMoves(characterName: name)
                moves = fetchedMoves
                overallSectionsKR = Array<Move>.overallSectionOrder(from: fetchedMoves)
                await relocalizeAndSort()
            } catch {
                NSLog("❌ Error fetching \(name)'s moves: \(error)")
            }
        }
    }
    
    func filter(by keyword: String) {
        let key = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            filtered = sortLocalized(localized)
            return
        }
        
        filtered = sortLocalized(
            localized.filter { lm in
                let attrMatch: Bool = {
                    if key.contains("파크") || key.contains("파워크러쉬") || key.contains("powercrush") {
                        return lm.attribute?.contains("powercrush") ?? false
                    }
                    return false
                }()
                return lm.skillNamePrimary.lowercased().contains(key)
                || (lm.skillNameSecondary?.lowercased().contains(key) ?? false)
                || lm.command.lowercased().contains(key)
                || (lm.commandEN?.lowercased().contains(key) ?? false)
                || (lm.description?.lowercased().contains(key) ?? false)
                || attrMatch
            }
        )
    }
    
    func resetFilter() {
        filtered = sortLocalized(localized)
    }
    
    // MARK: private functions
    
    private func relocalizeAndSort() async {
        // 상위에서 한 번에 로컬라이즈
        let mapped: [LocalizedMove] = await withTaskGroup(of: LocalizedMove.self, returning: [LocalizedMove].self) { group in
            for m in moves {
                group.addTask { await self.translator.localize(move: m, to: self.lang) }
            }
            var acc: [LocalizedMove] = []
            for await lm in group { acc.append(lm) }
            return acc
        }

        localized = mapped
        filtered  = sortLocalized(mapped)
    }
    
    private func sortLocalized(_ items: [LocalizedMove]) -> [LocalizedMove] {
        // 섹션 순서는:
        // 1) 언어별 선호 섹션 (preferredSections)
        // 2) 나머지는 "첫 등장 순서" 유지
        let sectionsInOrder: [String] = {
            let all = items.compactMap { $0.section }
            var seen = Set<String>()
            var order: [String] = []
            // 1) 선호 섹션
            for s in preferredSections where all.contains(s) {
                if seen.insert(s).inserted { order.append(s) }
            }
            // 2) 첫 등장 순
            for s in all where seen.insert(s).inserted {
                order.append(s)
            }
            return order
        }()

        func sectionPriority(_ sec: String?) -> (Int, Int) {
            guard let s = sec, let i = sectionsInOrder.firstIndex(of: s) else { return (1, .max) }
            return (0, i)
        }

        // 버튼 우선 정렬 키 (기존 로직 준수)
        let buttonOrder = ["lp","rp","lk","rk","ap","ak","1","2","3","4","6","7","8","9"]

        return items.sorted { a, b in
            // 1) 섹션
            let ls = sectionPriority(a.section)
            let rs = sectionPriority(b.section)
            if ls != rs {
                if ls.0 != rs.0 { return ls.0 < rs.0 }
                return ls.1 < rs.1
            }
            // 2) 커맨드 토큰 비교
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
            // 3) 동일 시 id
            return a.id < b.id
        }
    }
}

