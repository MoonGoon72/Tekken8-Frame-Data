//
//  CharacterListViewModel.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/3/25.
//

import Combine
import Foundation
import UIKit

@MainActor
protocol CharacterFetchable {
    func fetchCharacters()
}

@MainActor
protocol CharacterSelectable: ObservableObject {
    func filter(by keyword: String)
    func resetFilter()
    func loadImage(for character: Character) throws
    func image(for key: String) -> UIImage?
    var characterImagesPublisher: AnyPublisher<[String: UIImage], Never> { get }
    var filteredCharactersPublisher: AnyPublisher<[Character], Never> { get }
    var filteredCharacters: [Character] { get }
}

@MainActor
final class CharacterListViewModel: CharacterFetchable, CharacterSelectable {
    var characterImagesPublisher: AnyPublisher<[String : UIImage], Never> {
        return $characterImages
            .eraseToAnyPublisher()
    }
    var filteredCharactersPublisher: AnyPublisher<[Character], Never> {
        return $filteredCharacters
            .eraseToAnyPublisher()
    }
    @Published private(set) var characterImages: [String: UIImage] = [:]
    @Published private(set) var filteredCharacters: [Character] = []
    private(set) var characters: [Character] = []
    private var cancellables = Set<AnyCancellable>()
    private let repository: CharacterRepository
    private let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
    
    init(characterRepository repository: CharacterRepository) {
        self.repository = repository
        
        NotificationCenter.default.publisher(for: .allDatabaseDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchCharacters()
            }
            .store(in: &cancellables)
    }
    
    func fetchCharacters() {
        Task {
            do {
                let fetchedCharacters: [Character] = try await repository.fetchCharacters()
                characters = fetchedCharacters.sorted {
                    $0.localizedName(preferredLanguage: preferredLanguage)
                        .localizedStandardCompare(
                            $1.localizedName(preferredLanguage: preferredLanguage)
                        ) == .orderedAscending
                }
                filteredCharacters = characters
                for character in characters {
                    try loadImage(for: character)
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
            filteredCharacters = characters.filter {
                $0.nameKR.contains(keyword) || $0.nameEN.lowercased().contains(keyword.lowercased())
            }.sorted {
                $0.localizedName(preferredLanguage: preferredLanguage)
                    .localizedStandardCompare(
                        $1.localizedName(preferredLanguage: preferredLanguage)
                    ) == .orderedAscending
            }
        }
    }
    
    func resetFilter() {
        filteredCharacters = characters
    }
    
    func loadImage(for character: Character) throws {
        Task {
            let url = try repository.characterImageURL(character: character).absoluteString
            if let image = await ImageCacheManager.shared.fetch(for: url) {
                characterImages[character.nameEN] = image
            }
        }
    }
    
    func image(for key: String) -> UIImage? {
        return characterImages[key]
    }
}
