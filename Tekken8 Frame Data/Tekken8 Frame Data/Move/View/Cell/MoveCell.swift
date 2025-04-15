//
//  MoveCell.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/8/25.
//

import SwiftUI

struct MoveCell: View, ReuseIdentifiable {
    let move: Move
    
    var body: some View {
        HStack {
            Text("\(move.characterName)")
            Text("\(move.command)")
            Text("\(move.skillName)")
        }
    }
}

#Preview {
    let move = Move(id: 1, characterName: "니나 윌리엄스", section: "히트", skillName: "쉐캔", command: "6n23rp", judgment: "중", damage: "100", startup: "15f", guard: "+7", hit: "+14", counter: "+26", additionalInfo: "개사기")
    MoveCell(move: move)
}
