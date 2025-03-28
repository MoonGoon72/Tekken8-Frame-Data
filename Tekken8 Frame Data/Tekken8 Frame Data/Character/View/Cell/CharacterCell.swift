//
//  CharacterCell.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/28/25.
//

import SwiftUI

struct CharacterCell: View, ReuseIdentifiable {
    
    var character: Character
    
    var body: some View {
        HStack {
            
            Text(character.name)
        }
    }
}

#Preview {
    CharacterCell(character: Character(id: 1, name: "니나 윌리엄스", imageURL: "https://i.ibb.co/GXN7B5k/nina.png"))
}
