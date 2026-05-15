//
//  MoveListViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Combine
import Foundation

struct FilterCondition {
    var keyword: String = ""
    var sections: [String] = []
    var attributes: [String] = []
}

@MainActor
final class MoveListViewModel {
    @Published private(set) var filtered: [LocalizedMove] = []
    @Published var filterCondition: FilterCondition = FilterCondition()
    
    private var cancellables = Set<AnyCancellable>()
    private(set) var moves: [Move] = []
    private var localized: [LocalizedMove] = []
    private(set) var overallSections: [String] = []

    private let repository: MoveRepository
    private let translator = TranslatorEngine()
    
    private var lang: TranslatorEngine.Lang = (Bundle.main.preferredLocalizations.first == "ko" ? .ko : .en)
    private var preferredSections: [String] {
        switch lang {
        case .ko:
            return ["히트", "레이지", "일반", "앉은 상태"]
        case .en:
            return ["Heat", "Rage", "General", "While crouching"]
        }
    }
    
    init(moveRepository repository: MoveRepository) {
        self.repository = repository
        $filterCondition.sink { condition in
            self.filter(by: condition)
        }
        .store(in: &cancellables)
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
                await relocalizeAndSort()
            } catch {
                NSLog("❌ Error fetching \(name)'s moves: \(error)")
            }
        }
    }

    func updateKeyword(by keyword: String) {
        filterCondition.keyword = keyword
    }

    func applyFilter(_ condition: FilterCondition) {
        filterCondition.attributes = condition.attributes
        filterCondition.sections = condition.sections
    }

    private func filter(by condition: FilterCondition) {
        let keyword = condition.keyword
        let key = keyword.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty || !condition.attributes.isEmpty || !condition.sections.isEmpty else {
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
                || condition.sections.contains(lm.section)
                || condition.attributes.contains(lm.attribute ?? "")
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
        overallSections = Array<LocalizedMove>.overallSectionOrder(from: localized)
        filtered  = sortLocalized(mapped)
    }
    
    private func sortLocalized(_ items: [LocalizedMove]) -> [LocalizedMove] {
        // 섹션 순서는:
        // 1) 언어별 선호 섹션 (preferredSections)
        // 2) 나머지는 "첫 등장 순서" 유지

        func sectionPriority(_ sec: String?) -> (Int, Int) {
            guard let s = sec, let i = overallSections.firstIndex(of: s) else { return (1, .max) }
            return (0, i)
        }

        return items.sorted { a, b in
            // 1) 섹션
            let ls = sectionPriority(a.section)
            let rs = sectionPriority(b.section)
            if ls != rs {
                if ls.0 != rs.0 { return ls.0 < rs.0 }
                return ls.1 < rs.1
            }
            // 2) sortOrder 순서 정렬
            return a.sortOrder < b.sortOrder
        }
    }
}

