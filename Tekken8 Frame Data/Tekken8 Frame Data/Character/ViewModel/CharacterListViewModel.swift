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
