//
//  CharacterCell.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/28/25.
//

import Foundation
import SwiftUI

struct CharacterCell: View, ReuseIdentifiable {
    var character: Character
    var localizedName: (primary: String, secondary: String?) {
        let preferredLanguage = Bundle.main.preferredLocalizations.first
        if preferredLanguage == "ko" {
            return (character.nameKR, character.nameEN)
        } else {
            return (character.nameEN, nil)
        }
    }
    @ObservedObject var viewModel: CharacterListViewModel
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            characterImage

            VStack(alignment: .leading, spacing: 2) {
                Text(localizedName.primary)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                if let secondary = localizedName.secondary {
                    Text(secondary)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.leading, 4)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.trailing, 4)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var characterImage: some View {
        let img = viewModel.image(for: character)

        Image(uiImage: img ?? UIImage(named: "mokujin")!)
            .resizable()
            .scaledToFill()
            .frame(
                width: Constants.Literals.characterImageWidth,
                height: Constants.Literals.characterImageHeight
            )
            .clipShape(.rect(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.05))
            )
    }
}

private enum Constants {
    enum Literals {
        static let characterImageWidth = 120.0
        static let characterImageHeight = 90.0
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, nameEN: "Nina Williams", nameKR: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"), viewModel: CharacterListViewModel(characterRepository: DefaultCharacterRepository(manager: SupabaseManager(), coreData: CoreDataManager())))
}
