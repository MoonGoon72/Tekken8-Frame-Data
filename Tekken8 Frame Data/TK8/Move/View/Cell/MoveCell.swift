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

// MARK: Judgment View

struct JudgmentView: View {
    private let judgments: [String]

    init(judgment: String) {
        self.judgments = judgment.tokenizeJudgments()
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(judgments.enumerated()), id: \.0) { _, j in
                JudgeBadge(text: j)
            }
        }
    }
}

private struct JudgeBadge: View {
    let text: String

    private var backgroundColor: Color {
        switch text {
        case "상": return Color.red.opacity(0.75)
        case "중": return Color.yellow.opacity(0.75)
        case "하": return Color.blue.opacity(0.75)
        case "특중": return Color.green.opacity(0.75)
        default:   return Color.purple.opacity(0.75)
        }
    }

    var body: some View {
        Text(LocalizedStringKey(stringLiteral: text))
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
    }
}

// MARK: Spec View

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

// MARK: Command View

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
        let cmdSet = Set(GlobalConstants.commands)
        let onlyText = tokens.count == 1 && !cmdSet.contains(tokens.first ?? "")
        if onlyText {
            Text(tokens[0])
                .font(isDescription ? .subheadline : .system(size: 16))
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FlowLayout(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.0) { _, token in
                    if GlobalConstants.commands.contains(token) {
                        Image(token.contains("_") ? token + "hold" : token)
                            .resizable()
                            .scaledToFit()
                            .frame(width: isDescription ? 24 : 30, height: isDescription ? 24 : 30)
                            .fixedSize()
                    } else {
                        Text(token)
                            .font(isDescription ? .subheadline : .system(size: 16))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: DescriptionView

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

// MARK: Constants

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

// MARK: Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var fallbackWidth: CGFloat = UIScreen.main.bounds.width - 32 // 제안이 nil일 때 대비
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? fallbackWidth
        
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let measured = subview.sizeThatFits(.init(width: maxWidth, height: nil))
            let tokenWidth = min(measured.width, maxWidth)
            
            if lineWidth + tokenWidth > maxWidth, lineWidth > 0 {
                totalHeight += lineHeight + spacing
                lineWidth = 0
                lineHeight = 0
            }
            lineWidth += tokenWidth + spacing
            lineHeight = max(lineHeight, measured.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let measured = subview.sizeThatFits(.init(width: maxWidth, height: nil))
            let tokenWidth = min(measured.width, maxWidth)
            
            if x + tokenWidth > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .init(width: tokenWidth, height: measured.height))
            x += tokenWidth + spacing
            lineHeight = max(lineHeight, measured.height)
        }
    }
}

// MARK: Judgment Tokenize

private extension String {
    /// "중중중", "중,중,상", "상/중|하", "상 중 하" 모두 ["중","중","중"] 등으로 분리
    func tokenizeJudgments() -> [String] {
            let allowed = Set(["상", "중", "하", "특중", "특하", "상단가불", "중단가불", "가불"]) // ← 특중 추가
            let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            // 1) 구분자 기준 split
            let separators = CharacterSet(charactersIn: ",/|·・ㆍ").union(.whitespacesAndNewlines)
            let parts = trimmed.components(separatedBy: separators).filter { !$0.isEmpty }

            if parts.count > 1 {
                return parts.filter { allowed.contains($0) }
            }

            // 2) 단일 토큰인 경우: 전체가 allowed면 그대로 반환
            if allowed.contains(trimmed) {
                return [trimmed]
            }

            // 3) 글자 단위 fallback
            return trimmed.map { String($0) }.filter { allowed.contains($0) }
        }

    /// "상중하" → ["상","중","하"]; "중중중" → ["중","중","중"]
    func expandJudgmentRun() -> [String] {
        map { String($0) }.filter { ["상","중","하"].contains($0) }
    }
}

#Preview {
    let localizedMove = LocalizedMove(
        id: 1,
        section: "일반",
        skillNamePrimary: "초풍",
        skillNameSecondary: "초풍",
        command: "1n6ar",
        commandEN: "f,n,d,df+rp",
        judgment: "중단가불",
        damage: "100",
        startupFrame: "12",
        guardFrame: "5",
        hitFrame: "5",
        counterFrame: "3",
        attribute: "powercrush",
        description: "- "
    )
    MoveCell(move: localizedMove)
}
