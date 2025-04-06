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
                    .frame(height: 80)
                    .clipShape(.rect(cornerRadius: 15))
            } else {
                Image("mokujin")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 80)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 15))
            }
            Text(character.name)
                .font(.title2)
                .padding(.leading, 5)
            Spacer()
        }
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, name: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"), viewModel: CharacterListViewModel())
}
