//
//  CharacterListViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/3/25.
//

import Foundation
import UIKit

@MainActor
final class CharacterListViewModel: ObservableObject {
    @Published private(set) var characterImages: [Int: UIImage] = [:]
    @Published private(set) var filteredCharacters: [Character] = []
    private(set) var characters: [Character] = []
    private let repository: CharacterRepository
    
    init(characterRepository repository: CharacterRepository) {
        self.repository = repository
    }
    
    func fetchCharacters() {
        Task {
            do {
                let fetchedCharacters: [Character] = try await repository.fetchCharacters()
                characters = fetchedCharacters
                filteredCharacters = characters
                for character in characters {
                    loadImage(for: character)
                }
            } catch {
                NSLog("❌ Error fetching characters: \(error)")
            }
        }
    }
    
    func filter(by keyword: String) {
        if keyword.isEmpty {
            filteredCharacters = characters
        } else {
            filteredCharacters = characters.filter { $0.name.contains(keyword) }
        }
    }
    
    func resetFilter() {
        filteredCharacters = characters
    }
    
    func loadImage(for character: Character) {
        Task {
            if let image = await ImageCacheManager.shared.fetch(for: character.imageURL) {
                characterImages[character.id] = image
            }
        }
    }
    
    func image(for character: Character) -> UIImage? {
        return characterImages[character.id]
    }
}
