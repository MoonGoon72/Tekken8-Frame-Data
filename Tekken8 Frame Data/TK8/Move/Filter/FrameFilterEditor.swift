import SwiftUI

enum FrameFilterField: Hashable {
    case startupValue, startupUpper, guardValue, guardUpper
}

struct FrameFilterPreset: Identifiable {
    let mode: FrameFilterMode
    let first: Int
    var second: Int? = nil
    var id: String { "\(mode.rawValue)-\(first)-\(second.map(String.init) ?? "")" }

    var title: String {
        if let second { return "\(first) … \(second)" }
        return "\(mode.symbol) \(first)"
    }
}

struct FrameFilterEditor: View {
    @Binding var input: FrameFilterInput
    @FocusState.Binding var focusedField: FrameFilterField?
    let title: String
    let accent: Color
    let presets: [FrameFilterPreset]
    let firstField: FrameFilterField
    let secondField: FrameFilterField

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer(minLength: 8)
                Text(input.summary)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundStyle(input.isActive ? accent : .secondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 4) { modeButtons }
                FlowLayout(spacing: 4) { modeButtons }
            }

            if input.isActive {
                if input.mode == .range {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            valueField(text: $input.firstText, label: "Minimum", field: firstField)
                            Text("…").foregroundStyle(.secondary)
                            valueField(text: $input.secondText, label: "Maximum", field: secondField)
                        }
                        VStack(spacing: 12) {
                            valueField(text: $input.firstText, label: "Minimum", field: firstField)
                            valueField(text: $input.secondText, label: "Maximum", field: secondField)
                        }
                    }
                } else {
                    valueField(text: $input.firstText, label: input.mode.rawValue, field: firstField)
                }

                if let message = input.validationMessage {
                    Label(message.localized(), systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                        .accessibilityIdentifier("\(firstField).error")
                } else {
                    conditionDiagram
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick picks".localized())
                    .font(.caption).foregroundStyle(.secondary)
                FlowLayout(spacing: 8) {
                    ForEach(presets) { preset in
                        Button {
                            focusedField = nil
                            input.select(preset.mode, first: preset.first, second: preset.second)
                        } label: {
                            Text(preset.title)
                                .font(.subheadline.monospaced().weight(.medium))
                                .foregroundStyle(isSelected(preset) ? accent : .primary)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 44)
                                .background(isSelected(preset) ? accent.opacity(0.12) : Color(uiColor: .tertiarySystemGroupedBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(title), \(preset.mode.rawValue.localized()), \(preset.title)")
                        .accessibilityAddTraits(isSelected(preset) ? .isSelected : [])
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var modeButtons: some View {
        ForEach(FrameFilterMode.allCases, id: \.self) { mode in
            Button {
                focusedField = nil
                input.mode = mode
            } label: {
                Text(mode.rawValue.localized())
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(minHeight: 44)
                    .foregroundStyle(input.mode == mode ? accent : .secondary)
                    .background(input.mode == mode ? accent.opacity(0.14) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(input.mode == mode ? accent.opacity(0.45) : Color.clear)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title), \(mode.rawValue.localized())")
            .accessibilityAddTraits(input.mode == mode ? .isSelected : [])
            .accessibilityIdentifier("\(firstField).\(mode)")
        }
    }

    private func valueField(text: Binding<String>, label: String, field: FrameFilterField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.localized()).font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .font(.title2.monospaced().weight(.semibold))
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: field)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("\(title), \(label.localized())")
                    .accessibilityIdentifier("\(field).input")

                if input.allowsNegative {
                    Button {
                        text.wrappedValue = FrameFilterInput.togglingSign(of: text.wrappedValue)
                    } label: {
                        Text("±").font(.title3.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(accent.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .accessibilityLabel("\(title), \(label.localized()), \("Change sign".localized())")
                }
                Text("F").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(focusedField == field ? accent : Color.primary.opacity(0.12), lineWidth: focusedField == field ? 2 : 1)
            }
        }
        .frame(minWidth: input.allowsNegative ? 150 : 100, maxWidth: .infinity)
    }

    /// A symbolic condition, rather than a draggable scale with arbitrary limits.
    private var conditionDiagram: some View {
        HStack(spacing: 8) {
            if input.mode == .atMost { Image(systemName: "arrow.left") }
            Capsule().fill(input.mode == .atMost || input.mode == .range ? accent : accent.opacity(0.2))
                .frame(height: 3)
            Text(input.summary + " F")
                .font(.caption.monospaced().weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(accent.opacity(0.1)).clipShape(Capsule())
            Capsule().fill(input.mode == .atLeast || input.mode == .range ? accent : accent.opacity(0.2))
                .frame(height: 3)
            if input.mode == .atLeast { Image(systemName: "arrow.right") }
        }
        .foregroundStyle(accent)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(input.summary)")
    }

    private func isSelected(_ preset: FrameFilterPreset) -> Bool {
        var candidate = input
        candidate.select(preset.mode, first: preset.first, second: preset.second)
        return input.mode == preset.mode && input.selectedRange != nil && input.selectedRange == candidate.selectedRange
    }
}
