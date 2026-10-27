import SwiftUI
import UIKit
import XCTest
@testable import TK8

@MainActor
final class AppearanceContentTests: XCTestCase {
    func testCharacterAndMoveContentAdoptWindowThemeWithoutRecreation() async throws {
        let repository = InMemoryThemeRepository()
        let appearance = AppAppearance(repository: repository)
        let character = Character(id: 1, nameEN: "Nina", nameKR: "니나 윌리엄스", imageURL: "")
        let move = LocalizedMove(id: 1, sortOrder: 1, section: "일반", skillNamePrimary: "테마 확인용 기술",
            skillNameSecondary: "Move preview", command: "6n23rp", commandEN: nil,
            judgment: "상,중,하", damage: "24", startupFrame: "15", guardFrame: "-12", hitFrame: "+7",
            counterFrame: "Launch", attribute: nil, description: "기술 설명과 커맨드 4 4")
        var observedScheme: ColorScheme?
        let host = UIHostingController(rootView: VStack(spacing: 16) {
            CharacterCell(character: character, image: UIImage(named: "Nina"))
            MoveCell(move: move).fixedSize(horizontal: false, vertical: true)
            ThemeEnvironmentProbe { observedScheme = $0 }
            Spacer(minLength: 0)
        }.padding(16).background(Color.tkBackground))
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        appearance.register(window)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for theme in [AppTheme.dark, .light] {
            try appearance.select(theme)
            try? await Task.sleep(for: .milliseconds(300))
            host.view.layoutIfNeeded()
            XCTAssertEqual(host.traitCollection.userInterfaceStyle, theme.interfaceStyle)
            XCTAssertEqual(observedScheme, theme == .dark ? .dark : .light)
            let image = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Character-Move-\(theme.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testSelectedMemoKeepsNormalAppearanceOutsideEditingAcrossThemeChanges() async throws {
        let appearance = AppAppearance(repository: InMemoryThemeRepository())
        let root = UIViewController()
        let cell = MemoCollectionViewCell(frame: CGRect(x: 16, y: 16, width: 288, height: 100))
        root.view.addSubview(cell)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        appearance.register(window)
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        cell.isSelected = true

        for theme in [AppTheme.light, .dark] {
            try appearance.select(theme)
            try? await Task.sleep(for: .milliseconds(100))
            let traits = cell.traitCollection
            XCTAssertEqual(cell.contentView.backgroundColor?.resolvedColor(with: traits), UIColor.tkSurface.resolvedColor(with: traits),
                           "Opening a memo must not apply the editing highlight after a theme change")
            XCTAssertEqual(cell.contentView.layer.borderColor, UIColor.tkSeparator.resolvedColor(with: traits).cgColor)
        }

        cell.isSelected = false
        cell.setEditing(true, animated: false)
        cell.isSelected = true
        for theme in [AppTheme.light, .dark] {
            try appearance.select(theme)
            try? await Task.sleep(for: .milliseconds(100))
            let traits = cell.traitCollection
            XCTAssertEqual(cell.contentView.backgroundColor?.resolvedColor(with: traits), UIColor.tkPositive.withAlphaComponent(0.12).resolvedColor(with: traits))
            XCTAssertEqual(cell.contentView.layer.borderColor, UIColor.tkPositive.withAlphaComponent(0.25).resolvedColor(with: traits).cgColor)
        }
        cell.setEditing(false, animated: false)
        XCTAssertEqual(cell.contentView.backgroundColor?.resolvedColor(with: cell.traitCollection), UIColor.tkSurface.resolvedColor(with: cell.traitCollection),
                       "Leaving editing must clear the editing highlight even while the cell remains selected")
    }

    func testMemoTextAndLayerBordersUpdateWhenThemeChanges() async throws {
        let appearance = AppAppearance(repository: InMemoryThemeRepository())
        let root = UIViewController()
        let compose = MemoComposeView()
        root.view = compose
        let cell = MemoCollectionViewCell(frame: CGRect(x: 16, y: 300, width: 288, height: 100))
        cell.configure(memo: Memo(id: UUID(), characterName: "Nina", title: "메모 제목", body: "Nina\n메모 본문", isPinned: false, updatedAt: Date()), image: nil)
        compose.addSubview(cell)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        appearance.register(window)
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for theme in [AppTheme.dark, .light] {
            try appearance.select(theme)
            try? await Task.sleep(for: .milliseconds(100))
            compose.layoutIfNeeded()
            let traits = compose.traitCollection
            XCTAssertEqual(compose.bodyField.textColor?.resolvedColor(with: traits), UIColor.tkPrimaryText.resolvedColor(with: traits))
            let actual = try XCTUnwrap(cell.contentView.layer.borderColor)
            XCTAssertEqual(UIColor(cgColor: actual), UIColor.tkSeparator.resolvedColor(with: traits))
        }
    }
}

private struct ThemeEnvironmentProbe: View {
    @Environment(\.colorScheme) private var scheme
    let report: (ColorScheme) -> Void
    var body: some View {
        Color.clear.frame(height: 0)
            .onAppear { report(scheme) }
            .onChange(of: scheme) { _, value in report(value) }
    }
}

private final class InMemoryThemeRepository: AppThemeRepository {
    var theme: AppTheme = .dark
    func save(_ theme: AppTheme) throws { self.theme = theme }
}
