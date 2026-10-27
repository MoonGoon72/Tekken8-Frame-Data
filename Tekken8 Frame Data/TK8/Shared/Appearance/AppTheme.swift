import UIKit

enum AppTheme: String, Codable, CaseIterable {
    case dark, light, system

    var title: String {
        switch self {
        case .dark: return "Dark".localized()
        case .light: return "Light".localized()
        case .system: return "Follow system settings".localized()
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return .unspecified
        }
    }

    var symbolName: String {
        switch self {
        case .dark: return "moon.stars"
        case .light: return "sun.max"
        case .system: return "iphone"
        }
    }
}
