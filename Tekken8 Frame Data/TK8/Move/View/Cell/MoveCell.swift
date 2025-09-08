//
//  MoveCell.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/8/25.
//

import SwiftUI

struct MoveCell: View, ReuseIdentifiable {
    let move: LocalizedMove

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 기술명 + 커맨드
            HStack {
                Text(move.skillNamePrimary)
                    .font(.headline)
                    .padding(.horizontal, 3)
                if let attribute = move.attribute, attribute != "" {
                    AttributeView(attributes: attribute)
                }
                Spacer()
                if let sub = move.skillNameSecondary, !sub.isEmpty {
                    Text(sub).font(.subheadline)
                }
            }

            CommandView(command: move.command)
            
            JudgmentView(judgment: move.judgment ?? "-")

            SpecView(move: move)

            if let description = move.description, !description.isEmpty { DescriptionView(description: description) }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
        .onTapGesture {
            print(move.command)
            print(move.description ?? "")
        }
    }
}

struct AttributeView: View {
    private let attributes: String
    private let token: [String]
    
    init(attributes: String) {
        self.attributes = attributes
        token = attributes.components(separatedBy: ",")
    }
    var body: some View {
        ForEach(Array(token.enumerated()), id: \.0) { _, attribute in
            Image(attribute)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .padding(.horizontal, 3)
        }
    }
}

struct JudgmentView: View {
    private let judgment: String
    private let backgroundColor: Color
    
    init(judgment: String) {
        self.judgment = judgment
        switch judgment {
        case "상":
            backgroundColor = Color.red.opacity(0.75)
        case "중":
            backgroundColor = Color.yellow.opacity(0.75)
        case "하":
            backgroundColor = Color.blue.opacity(0.75)
        default:
            backgroundColor = Color.purple.opacity(0.75)
        }
    }
    
    var body: some View {
        Text(LocalizedStringKey(stringLiteral: judgment))
            .font(.caption)
            .padding(4)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

struct SpecView: View {
    private let move: LocalizedMove
    
    init(move: LocalizedMove) {
        self.move = move
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.Texts.damage)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(move.damage ?? "-")
                    .font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.Texts.startup)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(move.startupFrame ?? "-")
                    .font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.Texts.guard)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(move.guardFrame ?? "-")
                    .font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.Texts.hit)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(move.hitFrame ?? "-")
                    .font(.system(size: 13))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.Texts.counter)
                    .font(.system(size: 15))
                    .fontWeight(.semibold)
                Text(move.counterFrame ?? "-")
                    .font(.system(size: 13))
            }
        }
        .font(.caption)
    }
}

struct CommandView: View {
    private let command: String
    private let tokens: [String]
    private let isDescription: Bool
    
    init(command: String, isDescription: Bool = false) {
        self.command = command
        self.isDescription = isDescription
        tokens = command.tokenizeCommands()
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.0) { _, token in
                if GlobalConstants.commands.contains(token) {
                    Image(token.contains("_") ? token + "hold" : token)
                        .resizable()
                        .scaledToFit()
                        .frame(width: isDescription ? 24 : 30, height: isDescription ? 24 : 30)
                } else {
                    Text(token)
                        .font(isDescription ? .subheadline : .system(size: 16))
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct DescriptionView: View {
    private let description: String
    
    init(description: String) {
        self.description = description
    }
    
    var body: some View {
        Divider()
        ForEach(descriptionSplitter(description), id: \.self) { command in
            CommandView(command: command, isDescription: true)
        }
    }
    
    private func descriptionPrettyPrinter(_ description: String) -> String {
        let newDescription = description.replacingOccurrences(of: "| ", with: "\n")
        return newDescription
    }
    
    private func descriptionSplitter(_ description: String) -> [String] {
        return description.components(separatedBy: "| ")
    }
}

private enum Constants {
    enum Texts {
        static let damage: LocalizedStringKey = "데미지"
        static let startup: LocalizedStringKey = "발동"
        static let `guard`: LocalizedStringKey = "가드"
        static let hit: LocalizedStringKey = "히트"
        static let counter: LocalizedStringKey = "카운터"
        static let high: LocalizedStringKey = "상"
        static let middle: LocalizedStringKey = "중"
        static let low: LocalizedStringKey = "하"
    }
}

//#Preview {
//    let move = Move(id: 1, characterName: "니나 윌리엄스", section: "히트", skillNameEN: "shake cancel", skillNameKR: "쉐캔", skillNickname: "쉐이크 캔슬", command: "6n23rp", judgment: "중", damage: "100", startupFrame: "15f", guardFrame: "+7", hitFrame: "+14", counterFrame: "+26", attribute: "", description: "개사기")
//    MoveCell(move: move)
//}
