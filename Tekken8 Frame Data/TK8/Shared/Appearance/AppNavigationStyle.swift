import UIKit

@MainActor
enum AppNavigationStyle {
    static func apply(to bar: UINavigationBar?) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .tkBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.tkPrimaryText]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.tkPrimaryText]
        appearance.shadowColor = .clear
        bar?.standardAppearance = appearance
        bar?.scrollEdgeAppearance = appearance
        bar?.compactAppearance = appearance
        bar?.tintColor = .tkActionText
    }
}
