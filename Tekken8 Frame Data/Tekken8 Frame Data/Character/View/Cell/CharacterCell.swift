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
            Text(character.name)
                .font(.title2)
                .padding(.leading, Constants.Literals.cellPadding)
            Spacer()
            Image(systemName: "chevron.right")
                .padding(.trailing, Constants.Literals.cellPadding)
        }
    }
}

private enum Constants {
    enum Literals {
        static let characterImageHeight = 80.0
        static let characterImageCornerRadius = 15.0
        static let cellPadding = 5.0
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, name: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"), viewModel: CharacterListViewModel(characterRepository: DefaultCharacterRepository(manager: SupabaseManager(), coreData: CoreDataManager())))
}
