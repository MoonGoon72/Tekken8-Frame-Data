//
//  CharacterLayoutPreference.swift
//  TK8
//

import Foundation

final class CharacterLayoutPreference {
    let manager: UserDefaultsManageable

    init(manager: UserDefaultsManageable) {
        self.manager = manager
    }

    func fetchLayoutMode() -> CharacterCollectionViewMode {
        return (try? manager.fetch(CharacterCollectionViewMode.self, forKey: Constants.key)) ?? .list
    }

    func updateLayoutMode(_ mode: CharacterCollectionViewMode) {
        try? manager.update(mode, forKey: Constants.key)
    }
}

private extension CharacterLayoutPreference {
    enum Constants {
        static let key = "characterLayout"
    }
}
