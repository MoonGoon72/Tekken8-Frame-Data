//
//  FilterView.swift
//  TK8
//

import SwiftUI

// MARK: - Design Tokens

private extension Color {
    static let tk8Bg0        = Color(hex: "#0A0F18")
    static let tk8Bg2        = Color(hex: "#1A2230")
    static let tk8Bg3        = Color(hex: "#232C3D")
    static let tk8Red        = Color(hex: "#E63950")
    static let tk8Heat       = Color(hex: "#FF7A2E")
    static let tk8Safe       = Color(hex: "#4ED1A1")
    static let tk8Warn       = Color(hex: "#FFC857")
    static let tk8JudgeLow   = Color(hex: "#6BB6FF")
    static let tk8JudgeThrow = Color(hex: "#C99CFF")
    static let tk8Text1      = Color.white
    static let tk8Text2      = Color.white.opacity(0.72)
    static let tk8Text3      = Color.white.opacity(0.50)
    static let tk8Text4      = Color.white.opacity(0.32)
    static let tk8Hairline   = Color.white.opacity(0.07)
    static let tk8Hairline2  = Color.white.opacity(0.14)

    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb & 0xFF0000) >> 16) / 255,
            green: Double((rgb & 0x00FF00) >> 8)  / 255,
            blue:  Double( rgb & 0x0000FF)         / 255
        )
    }
}

// MARK: - Filter State

struct FilterState: Equatable {
    var sections: [ChipItem] = []
    var attributes: [ChipItem] = []
    var startupMin: Int = 0
    var startupMax: Int = 40
    var guardMin: Int = -40
    var guardMax: Int = 30

    var activeCount: Int {
        sections.count + attributes.count
        + (startupMin != 0 || startupMax != 40 ? 1 : 0)
        + (guardMin != -40 || guardMax != 30 ? 1: 0)
    }

    mutating func reset() {
        sections = []; attributes = []
        startupMin = 0; startupMax = 40
        guardMin = -40; guardMax = 30
    }
}

struct FilterView: View {
    @State var state: FilterState
    @Environment(\.dismiss) private var dismiss
    let moveListViewModel: MoveListViewModel

    init(moveListViewModel: MoveListViewModel) {
        self.moveListViewModel = moveListViewModel
        state = FilterState(
            sections: moveListViewModel.filterCondition.sections.map { .text(text: $0) },
            attributes: moveListViewModel.filterCondition.attributes.map { .icon(text: $0) }
        )
        sectionOptions = moveListViewModel.overallSections.map { ChipItem.text(text: $0) }
    }

    private let sectionOptions: [ChipItem]
    private let attributeOptions: [ChipItem] = [.icon(text: "heatburst"), .icon(text: "homing"), .icon(text: "wall_break"), .icon(text: "floor_break"), .icon(text: "tornado")]
    var body: some View {
        VStack {
            header
            Divider().background(Color.tk8Hairline)

            ScrollView {
                VStack(spacing: 0) {
                    sectionBlock
                    separator
                    attributeBlock
                }
            }
            footer
        }
        .background(.tkBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("필터".localized())
                .font(.system(size: 17, weight: .heavy))
                .foregroundStyle(.white)

            if state.activeCount > 0 {
                Text("\(state.activeCount)")
                    .font(.system(size: 10, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.tkRed)
                    .clipShape(Capsule())
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tk8Text2)
                    .frame(width: 28, height: 28)
                    .background(Color.tk8Bg2)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider().background(Color.tk8Hairline)
            HStack(spacing: 10) {
                Button("초기화".localized()) {
                    state.reset()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.tk8Text2)
                .frame(width: 70, height: 48)

                Button {
                    apply()
                    dismiss()
                } label: {
                    Text("적용".localized())
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.tk8Red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.tk8Red.opacity(0.38), radius: 14, y: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Helpers

    private var separator: some View {
        Divider()
            .background(Color.tk8Hairline)
            .padding(.horizontal, 20)
    }

    // MARK: - Section Block

    private var sectionBlock: some View {
        FilterBlock(
            title: "섹션".localized(),
            hint: "\(state.sections.count) / \(sectionOptions.count)",
            clearAction: state.sections.isEmpty ? nil : { state.sections = [] }) {
                FlowLayout(spacing: 6) {
                    ForEach(sectionOptions, id: \.self) { option in
                        ChipButton(
                            item: option,
                            color: .tkRed,
                            isActive: state.sections.contains(option)) {
                                state.sections.toggle(option)
                            }
                    }
                }
            }
    }

    // MARK: - Attribute Block

    private var attributeBlock: some View {
        FilterBlock(
            title: "속성".localized(),
            hint: "\(state.attributes.count) / \(attributeOptions.count)",
            clearAction: state.attributes.isEmpty ? nil : { state.attributes = [] }) {
                FlowLayout(spacing: 6) {
                    ForEach(attributeOptions, id: \.self) { option in
                        ChipButton(
                            item: option,
                            color: .tkRed,
                            isActive: state.attributes.contains(option)) {
                                state.attributes.toggle(option)
                            }
                    }
                }
            }
    }

    // MARK: - Startup Block
    

    private func apply() {
        var filterCondition = FilterCondition()
        filterCondition.sections = state.sections.map { $0.value }
        filterCondition.attributes = state.attributes.map { $0.value }
        filterCondition.keyword = moveListViewModel.filterCondition.keyword
        moveListViewModel.applyFilter(filterCondition)
    }
}

// MARK: - FilterBlock

private struct FilterBlock<Action: View, Content: View>: View {
    let title: String
    let hint: String?
    var clearAction: (() -> Void)? = nil
    var action: Action? = nil
    @ViewBuilder let content: Content

    init(
        title: String,
        hint: String?,
        clearAction: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) where Action == EmptyView {
        self.title = title
        self.hint = hint
        self.clearAction = clearAction
        self.action = nil
        self.content = content()
    }

    init(
        title: String,
        hint: String? = nil,
        action: Action,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.hint = hint
        self.clearAction = nil
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .kerning(0.18 * 11)
                    .foregroundStyle(Color.tk8Text2)

                if let hint {
                    Text(hint)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.tk8Text4)
                }

                Spacer()

                if let clearAction {
                    Button("지우기".localized(), action: clearAction)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.tk8Text3)
                } else if let action {
                    action
                }
            }
            content
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
    }
}

// MARK: - ChipButton

private struct ChipButton: View {
    let item: ChipItem
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch item {
            case .text(let text):
                Text(text)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isActive ? .white : Color.tk8Text2)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(isActive ? color : Color.tk8Bg2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? color : Color.tk8Hairline, lineWidth: 0.5)
                    )
            case .icon(let text):
                Image(text)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .opacity(isActive ? 1 : 0.62)
            }

        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Helpers

private extension Array where Element == ChipItem {
    mutating func toggle(_ value: ChipItem) {
        if contains(value) {
            removeAll { $0 == value }
        }
        else {
            append(value)
        }
    }
}

//#Preview {
//    FilterView(sectionOptions: [.text(text: "일반"), .text(text: "히트")])
//}
