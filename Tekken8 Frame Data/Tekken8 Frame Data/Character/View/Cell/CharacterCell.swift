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
    @State private var image: UIImage? = nil
    
    var body: some View {
        HStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: 80, height: 80)
                    .clipShape(.rect(cornerRadius: 15))
            } else {
                ProgressView()
                    .frame(width: 80, height: 80)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(.rect(cornerRadius: 15))
                    .task {
                        image = await ImageCacheManager.shared.fetch(for: character.imageURL)
                    }
            }
            Spacer()
            Text(character.name)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, name: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"))
}
