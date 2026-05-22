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
    static let startupBounds = 0...40
    static let guardBounds = -40...30

    var sections: [ChipItem] = []
    var attributes: [ChipItem] = []
    var startupMin: Int = 0
    var startupMax: Int = 40
    var guardMin: Int = -40
    var guardMax: Int = 30

    var isStartupDefault: Bool {
        startupMin == Self.startupBounds.lowerBound && startupMax == Self.startupBounds.upperBound
    }

    var isGuardDefault: Bool {
        guardMin == Self.guardBounds.lowerBound && guardMax == Self.guardBounds.upperBound
    }

    var activeCount: Int {
        sections.count + attributes.count
        + (isStartupDefault ? 0 : 1)
        + (isGuardDefault ? 0 : 1)
    }

    mutating func reset() {
        sections = []; attributes = []
        resetStartup()
        resetGuard()
    }

    mutating func resetStartup() {
        startupMin = Self.startupBounds.lowerBound
        startupMax = Self.startupBounds.upperBound
    }

    mutating func resetGuard() {
        guardMin = Self.guardBounds.lowerBound
        guardMax = Self.guardBounds.upperBound
    }
}

struct FilterView: View {
    @State var state: FilterState
    @Environment(\.dismiss) private var dismiss
    let moveListViewModel: MoveListViewModel

    init(moveListViewModel: MoveListViewModel) {
        self.moveListViewModel = moveListViewModel
        let condition = moveListViewModel.filterCondition
        let startupRange = condition.startupRange ?? FilterState.startupBounds
        let guardRange = condition.guardRange ?? FilterState.guardBounds

        state = FilterState(
            sections: condition.sections.map { .text(text: $0) },
            attributes: condition.attributes.map { .icon(text: $0) },
            startupMin: Self.clamp(startupRange.lowerBound, in: FilterState.startupBounds),
            startupMax: Self.clamp(startupRange.upperBound, in: FilterState.startupBounds),
            guardMin: Self.clamp(guardRange.lowerBound, in: FilterState.guardBounds),
            guardMax: Self.clamp(guardRange.upperBound, in: FilterState.guardBounds)
        )
        sectionOptions = moveListViewModel.overallSections.map { ChipItem.text(text: $0) }
    }

    private let sectionOptions: [ChipItem]
    private let attributeOptions: [ChipItem] = [.icon(text: "heatburst"), .icon(text: "homing"), .icon(text: "powercrush"), .icon(text: "wall_break"), .icon(text: "floor_break"), .icon(text: "tornado")]
    private let startupPresets: [FrameRangePreset] = [
        .init(title: "10~12", range: 10...12),
        .init(title: "13~15", range: 13...15),
        .init(title: "16~20", range: 16...20),
        .init(title: "21+", range: 21...FilterState.startupBounds.upperBound)
    ]
    private let guardPresets: [FrameRangePreset] = [
        .init(title: "<= -15", range: FilterState.guardBounds.lowerBound...(-15)),
        .init(title: "-14~-10", range: -14...(-10)),
        .init(title: "-9~-1", range: -9...(-1)),
        .init(title: ">= 0", range: 0...FilterState.guardBounds.upperBound)
    ]

    var body: some View {
        VStack {
            header
            Divider().background(Color.tk8Hairline)

            ScrollView {
                VStack(spacing: 0) {
                    sectionBlock
                    separator
                    attributeBlock
                    separator
                    startupBlock
                    separator
                    guardBlock
                }
            }
            footer
        }
        .background(.tkBackground)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Filter".localized())
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
                Button("Reset".localized()) {
                    state.reset()
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.tk8Text2)
                .frame(width: 70, height: 48)

                Button {
                    apply()
                    dismiss()
                } label: {
                    Text("Apply".localized())
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
            title: "Section".localized(),
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
            title: "Attribute".localized(),
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

    private var startupBlock: some View {
        FilterBlock(
            title: "Startup Frame".localized(),
            hint: "\(Self.formatPlainFrame(state.startupMin)) - \(Self.formatPlainFrame(state.startupMax))",
            clearAction: state.isStartupDefault ? nil : { state.resetStartup() }) {
                FrameRangeControl(
                    lowerValue: $state.startupMin,
                    upperValue: $state.startupMax,
                    bounds: FilterState.startupBounds,
                    accent: .tk8Heat,
                    presets: startupPresets,
                    valueFormatter: Self.formatPlainFrame
                )
            }
    }

    // MARK: - Guard Block

    private var guardBlock: some View {
        FilterBlock(
            title: "Guard Frame".localized(),
            hint: "\(Self.formatSignedFrame(state.guardMin)) - \(Self.formatSignedFrame(state.guardMax))",
            clearAction: state.isGuardDefault ? nil : { state.resetGuard() }) {
                FrameRangeControl(
                    lowerValue: $state.guardMin,
                    upperValue: $state.guardMax,
                    bounds: FilterState.guardBounds,
                    accent: .tk8Safe,
                    presets: guardPresets,
                    valueFormatter: Self.formatSignedFrame
                )
            }
    }

    private func apply() {
        var filterCondition = FilterCondition()
        filterCondition.sections = state.sections.map { $0.value }
        filterCondition.attributes = state.attributes.map { $0.value }
        filterCondition.keyword = moveListViewModel.filterCondition.keyword
        filterCondition.startupRange = state.isStartupDefault ? nil : state.startupMin...state.startupMax
        filterCondition.guardRange = state.isGuardDefault ? nil : state.guardMin...state.guardMax
        moveListViewModel.applyFilter(filterCondition)
    }

    private static func clamp(_ value: Int, in bounds: ClosedRange<Int>) -> Int {
        min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    private static func formatPlainFrame(_ value: Int) -> String {
        "\(value)"
    }

    private static func formatSignedFrame(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
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
                    Button("Clear".localized(), action: clearAction)
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

// MARK: - Frame Range Control

private struct FrameRangePreset: Hashable {
    let title: String
    let range: ClosedRange<Int>
}

private struct FrameRangeControl: View {
    @Binding var lowerValue: Int
    @Binding var upperValue: Int

    let bounds: ClosedRange<Int>
    let accent: Color
    let presets: [FrameRangePreset]
    let valueFormatter: (Int) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                FrameValuePill(text: valueFormatter(lowerValue), accent: accent)

                Rectangle()
                    .fill(Color.tk8Hairline2)
                    .frame(height: 1)

                FrameValuePill(text: valueFormatter(upperValue), accent: accent)
            }

            RangeSliderView(
                lowerValue: $lowerValue,
                upperValue: $upperValue,
                bounds: bounds,
                accent: accent,
                valueFormatter: valueFormatter
            )

            FlowLayout(spacing: 6) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        lowerValue = preset.range.lowerBound
                        upperValue = preset.range.upperBound
                    } label: {
                        Text(preset.title.localized())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isActive(preset) ? .white : Color.tk8Text2)
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(isActive(preset) ? accent : Color.tk8Bg2)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9)
                                    .stroke(isActive(preset) ? accent : Color.tk8Hairline, lineWidth: 0.5)
                            )
                    }
                }
            }
        }
    }

    private func isActive(_ preset: FrameRangePreset) -> Bool {
        lowerValue == preset.range.lowerBound && upperValue == preset.range.upperBound
    }
}

private struct FrameValuePill: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .monospaced))
            .foregroundStyle(.white)
            .frame(minWidth: 58)
            .frame(height: 30)
            .background(accent.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent.opacity(0.42), lineWidth: 0.5)
            )
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
