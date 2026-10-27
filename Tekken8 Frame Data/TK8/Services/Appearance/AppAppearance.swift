import Combine
import UIKit

/// UIKit 모달과 SwiftUI hosting이 같은 window trait를 상속하게 한다.
@MainActor
final class AppAppearance {
    @Published private(set) var theme: AppTheme
    private let repository: any AppThemeRepository
    private let windows = NSHashTable<UIWindow>.weakObjects()

    init(repository: any AppThemeRepository) {
        self.repository = repository
        theme = repository.theme
    }

    func register(_ window: UIWindow) {
        windows.add(window)
        window.overrideUserInterfaceStyle = theme.interfaceStyle
    }

    func select(_ theme: AppTheme) throws {
        guard self.theme != theme else { return }
        // 저장이 실패하면 현재 보이는 테마와 선택 상태를 함께 유지한다.
        try repository.save(theme)
        self.theme = theme
        windows.allObjects.forEach { $0.overrideUserInterfaceStyle = theme.interfaceStyle }
    }
}
