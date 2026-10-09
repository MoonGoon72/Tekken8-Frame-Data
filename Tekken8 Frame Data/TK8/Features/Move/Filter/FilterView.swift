//
//  FilterView.swift
//  TK8
//

import SwiftUI

private extension Color {
    static let tk8Red = Color(red: 0.90, green: 0.22, blue: 0.31)
}

// MARK: - Filter State

struct FilterState: Equatable {
    var sections: [ChipItem] = []
    var attributes: [ChipItem] = []
    var startup = FrameFilterInput(allowsNegative: false)
    var guardFrame = FrameFilterInput(allowsNegative: true)

    var isStartupDefault: Bool { !startup.isActive }
    var isGuardDefault: Bool { !guardFrame.isActive }
    var isValid: Bool { startup.validationMessage == nil && guardFrame.validationMessage == nil }

    var activeCount: Int {
        sections.count + attributes.count
        + (isStartupDefault ? 0 : 1)
        + (isGuardDefault ? 0 : 1)
    }

    mutating func reset() { self = FilterState() }
}

struct FilterView: View {
    @State var state: FilterState
    @FocusState private var focusedField: FrameFilterField?
    @Environment(\.dismiss) private var dismiss
    let moveListViewModel: MoveListViewModel
    let characterID: String
    let analytics: AnalyticsClient

    init(
        moveListViewModel: MoveListViewModel,
        characterID: String,
        analytics: AnalyticsClient
    ) {
        self.moveListViewModel = moveListViewModel
        self.characterID = characterID
        self.analytics = analytics
        let condition = moveListViewModel.filterCondition
        state = FilterState(
            sections: condition.sections.map { .text(text: $0) },
            attributes: condition.attributes.map { .icon(text: $0) },
            startup: FrameFilterInput(selectedRange: condition.startupRange, allowsNegative: false),
            guardFrame: FrameFilterInput(selectedRange: condition.guardRange, allowsNegative: true)
        )
        sectionOptions = moveListViewModel.overallSections.map { ChipItem.text(text: $0) }
    }

    private let sectionOptions: [ChipItem]
    private let attributeOptions: [ChipItem] = [.icon(text: "heatburst"), .icon(text: "homing"), .icon(text: "powercrush"), .icon(text: "tornado"), .icon(text: "wall_break"), .icon(text: "floor_break")]
    private let startupPresets: [FrameFilterPreset] = [
        .init(mode: .exact, first: 10),
        .init(mode: .exact, first: 15),
        .init(mode: .atMost, first: 15),
        .init(mode: .atLeast, first: 21)
    ]
    private let guardPresets: [FrameFilterPreset] = [
        .init(mode: .atMost, first: -15),
        .init(mode: .range, first: -14, second: -10),
        .init(mode: .atLeast, first: -9),
        .init(mode: .atLeast, first: 0)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a condition, then enter frames.".localized())
                        .font(.subheadline).foregroundStyle(.secondary)
                    startupBlock
                    guardBlock
                    Text("Moves with variable frames match when any value meets your condition.".localized())
                        .font(.caption).foregroundStyle(.secondary)
                    sectionBlock
                    attributeBlock
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            footer
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done".localized()) { focusedField = nil }
            }
        }
        .onAppear { analytics.log(.screenViewed(.moveFilter)) }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Button("Reset".localized()) {
                    reset()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .frame(minHeight: 48)

                Button {
                    focusedField = nil
                    apply()
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Text("Apply".localized())
                        if state.activeCount > 0 {
                            Text("(\(state.activeCount))").monospacedDigit()
                        }
                    }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(state.isValid ? Color.tk8Red : Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(!state.isValid)
                .accessibilityIdentifier("filter.apply")
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
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

    // MARK: - Frame editors

    private var startupBlock: some View {
        FrameFilterEditor(
            input: $state.startup,
            focusedField: $focusedField,
            title: "Startup Frame".localized(),
            accent: .orange,
            presets: startupPresets,
            firstField: .startupValue,
            secondField: .startupUpper
        )
    }

    private var guardBlock: some View {
        FrameFilterEditor(
            input: $state.guardFrame,
            focusedField: $focusedField,
            title: "Guard Frame".localized(),
            accent: .teal,
            presets: guardPresets,
            firstField: .guardValue,
            secondField: .guardUpper
        )
    }

    private func apply() {
        guard state.isValid else { return }
        let activeFilterCount = state.activeCount
        var filterCondition = FilterCondition()
        filterCondition.sections = state.sections.map { $0.value }
        filterCondition.attributes = state.attributes.map { $0.value }
        filterCondition.keyword = moveListViewModel.filterCondition.keyword
        filterCondition.startupRange = state.startup.selectedRange
        filterCondition.guardRange = state.guardFrame.selectedRange
        moveListViewModel.applyFilter(filterCondition)

        guard activeFilterCount > 0 else { return }
        analytics.log(.filterApplied(
            characterID: characterID,
            activeFilterCount: activeFilterCount,
            sectionCount: state.sections.count,
            attributeCount: state.attributes.count,
            startupRangeActive: !state.isStartupDefault,
            guardRangeActive: !state.isGuardDefault,
            resultCount: moveListViewModel.filtered.count
        ))
    }

    private func reset() {
        let previousActiveFilterCount = state.activeCount
        guard previousActiveFilterCount > 0 else { return }
        focusedField = nil
        state.reset()
        analytics.log(.filterReset(
            characterID: characterID,
            previousActiveFilterCount: previousActiveFilterCount
        ))
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
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let hint {
                    Text(hint)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let action {
                    action
                } else {
                    // Keep the same header geometry before the first selection.
                    Button("Clear".localized()) { clearAction?() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minHeight: 44)
                        .opacity(clearAction == nil ? 0 : 1)
                        .disabled(clearAction == nil)
                        .accessibilityHidden(clearAction == nil)
                }
            }
            content
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isActive ? Color.white : Color.primary)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(isActive ? color : Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? color : Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            case .icon(let text):
                Image(text)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .padding(5)
                    .background(isActive ? color.opacity(0.2) : Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isActive ? color : Color.clear, lineWidth: 2)
                    }
            }

        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.value.localized())
        .accessibilityAddTraits(isActive ? .isSelected : [])
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
