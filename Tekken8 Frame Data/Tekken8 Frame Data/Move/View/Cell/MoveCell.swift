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
        VStack(alignment: .leading, spacing: 8) {
            // 기술명 + 커맨드
            HStack {
                Text(move.skillNameEN)
                    .font(.headline)
                Spacer()
                Text(move.skillNameKR ?? "")
                    .font(.subheadline)
            }

            CommandView(command: move.command ?? "")
            
            // 판정
            JudgmentView(judgment: move.judgment ?? "-")
//            HStack(spacing: 8) {
//                Text(move.judgment ?? "")
//                    .font(.caption)
//                    .padding(4)
//                    .background(Color.gray.opacity(0.2))
//                    .cornerRadius(4)
//            }

            // 데미지, 발동 등 주요 수치
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("💥 데미지")
                    Text(move.damage ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("⏱ 발동")
                    Text(move.startupFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("🛡 가드")
                    Text(move.guardFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("✅ 히트")
                    Text(move.hitFrame ?? "-")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("⚡️ 카운터")
                    Text(move.counterFrame ?? "-")
                }
            }
            .font(.caption)

            // 추가 설명
            if let description = move.description, !description.isEmpty {
                let description = descriptionPrettyPrinter(description)
                Text("\(description)")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
    
    private func descriptionPrettyPrinter(_ description: String) -> String {
        let newDescription = description.replacingOccurrences(of: "| ", with: "\n")
        return newDescription
    }
}

struct JudgmentView: View {
    let judgment: String
    let backgroundColor: Color
    
    init(judgment: String) {
        self.judgment = judgment
        switch judgment {
        case "상":
            backgroundColor = Color.red.opacity(0.2)
        case "중":
            backgroundColor = Color.yellow.opacity(0.2)
        case "하":
            backgroundColor = Color.blue.opacity(0.2)
        default:
            backgroundColor = Color.purple.opacity(0.2)
        }
    }
    
    var body: some View {
        Text(judgment)
            .font(.caption)
            .padding(4)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

struct CommandView: View {
    let command: String
    let tokens: [String]
    
    init(command: String) {
        self.command = command
        tokens = command.tokenizeCommands()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.0) { _, token in
                if GlobalConstants.commands.contains(token) {
                    Image(token.contains("_") ? token + "hold" : token)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                } else {
                    Text(token)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

private enum Constants {

}

#Preview {
    let move = Move(id: 1, characterName: "니나 윌리엄스", section: "히트", skillNameEN: "shake cancel", skillNameKR: "쉐캔", skillNickname: "쉐이크 캔슬", command: "6n23rp", judgment: "중", damage: "100", startupFrame: "15f", guardFrame: "+7", hitFrame: "+14", counterFrame: "+26", attribute: "", description: "개사기")
    MoveCell(move: move)
}
