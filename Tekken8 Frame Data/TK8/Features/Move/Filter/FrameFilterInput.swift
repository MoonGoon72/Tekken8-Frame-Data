import Foundation

enum FrameFilterMode: String, CaseIterable {
    case any = "Any"
    case exact = "Exactly"
    case atLeast = "At least"
    case atMost = "At most"
    case range = "Range"

    var symbol: String {
        switch self {
        case .any: return "∞"
        case .exact: return "="
        case .atLeast: return "≥"
        case .atMost: return "≤"
        case .range: return "↔"
        }
    }
}

/// Keeps unfinished text in the filter screen without changing the applied condition.
struct FrameFilterInput: Equatable {
    var mode: FrameFilterMode = .any
    var firstText: String
    var secondText: String
    let allowsNegative: Bool

    init(selectedRange: ClosedRange<Int>? = nil, allowsNegative: Bool) {
        self.allowsNegative = allowsNegative
        firstText = allowsNegative ? "-10" : "15"
        secondText = allowsNegative ? "0" : "20"
        guard let selectedRange else { return }

        if selectedRange.lowerBound == selectedRange.upperBound {
            mode = .exact
            firstText = String(selectedRange.lowerBound)
        } else if selectedRange.upperBound == Int.max {
            mode = .atLeast
            firstText = String(selectedRange.lowerBound)
        } else if selectedRange.lowerBound == Int.min {
            mode = .atMost
            firstText = String(selectedRange.upperBound)
        } else {
            mode = .range
            firstText = String(selectedRange.lowerBound)
            secondText = String(selectedRange.upperBound)
        }
    }

    var isActive: Bool { mode != .any }

    var validationMessage: String? {
        guard isActive else { return nil }
        guard let first = Self.number(firstText),
              mode != .range || Self.number(secondText) != nil else {
            return "Enter a whole number."
        }
        if !allowsNegative && (first < 0 || (mode == .range && Self.number(secondText)! < 0)) {
            return "Startup frames must be zero or greater."
        }
        if mode == .range, let second = Self.number(secondText), first > second {
            return "Minimum must not exceed maximum."
        }
        return nil
    }

    var selectedRange: ClosedRange<Int>? {
        guard isActive, validationMessage == nil, let first = Self.number(firstText) else { return nil }
        switch mode {
        case .any: return nil
        case .exact: return first...first
        case .atLeast: return first...Int.max
        case .atMost: return Int.min...first
        case .range:
            guard let second = Self.number(secondText) else { return nil }
            return first...second
        }
    }

    var summary: String {
        guard isActive else { return "Any".localized() }
        guard validationMessage == nil, let first = Self.number(firstText) else { return "—" }
        if mode == .range, let second = Self.number(secondText) {
            return "\(formatted(first)) … \(formatted(second))"
        }
        return "\(mode.symbol) \(formatted(first))"
    }

    mutating func select(_ mode: FrameFilterMode, first: Int, second: Int? = nil) {
        self.mode = mode
        firstText = String(first)
        if let second { secondText = String(second) }
    }

    static func togglingSign(of text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "−", with: "-")
        if trimmed.hasPrefix("-") { return String(trimmed.dropFirst()) }
        if trimmed.hasPrefix("+") { return "-" + trimmed.dropFirst() }
        return "-" + trimmed
    }

    private static func number(_ text: String) -> Int? {
        Int(text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "−", with: "-"))
    }

    private func formatted(_ value: Int) -> String {
        allowsNegative && value > 0 ? "+\(value)" : String(value)
    }
}
