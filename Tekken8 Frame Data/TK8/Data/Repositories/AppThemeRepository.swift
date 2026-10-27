import Foundation

protocol AppThemeRepository {
    var theme: AppTheme { get }
    func save(_ theme: AppTheme) throws
}

final class DefaultAppThemeRepository: AppThemeRepository {
    private let manager: any UserDefaultsManageable
    private let key = "app_theme"

    init(manager: any UserDefaultsManageable) {
        self.manager = manager
    }

    var theme: AppTheme { (try? manager.fetch(AppTheme.self, forKey: key)) ?? .dark }

    func save(_ theme: AppTheme) throws {
        try manager.update(theme, forKey: key)
    }
}
