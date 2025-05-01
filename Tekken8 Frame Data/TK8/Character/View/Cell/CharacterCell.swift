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
    @ObservedObject var viewModel: CharacterListViewModel
    
    var body: some View {
        HStack(alignment: .center) {
            if let image = viewModel.image(for: character) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: Constants.Literals.characterImageHeight)
                    .clipShape(.rect(cornerRadius: Constants.Literals.characterImageCornerRadius))
            } else {
                Image("mokujin")
                    .resizable()
                    .scaledToFit()
                    .frame(height: Constants.Literals.characterImageHeight)
                    .clipShape(.rect(cornerRadius: Constants.Literals.characterImageCornerRadius))
            }
            VStack(alignment: .leading) {
                Text(character.nameKR)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.leading, Constants.Literals.cellPadding)
                Text(character.nameEN)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, Constants.Literals.cellPadding)
            }
            .padding(.leading, Constants.Literals.cellPadding)
            Spacer()
            Image(systemName: "chevron.right")
                .padding(.trailing, Constants.Literals.cellPadding)
        }
        .padding(4)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

private enum Constants {
    enum Literals {
        static let characterImageHeight = 95.0
        static let characterImageCornerRadius = 10.0
        static let cellPadding = 5.0
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, nameEN: "Nina Williams", nameKR: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"), viewModel: CharacterListViewModel(characterRepository: DefaultCharacterRepository(manager: SupabaseManager(), coreData: CoreDataManager())))
}
