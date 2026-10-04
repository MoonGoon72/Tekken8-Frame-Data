@testable import TK8
import SwiftUI
import UIKit
import XCTest

@MainActor
final class FrameFilterLayoutTests: XCTestCase {
    func test_small_screen_with_accessibility_text_keeps_range_inputs_inside_scroll_width() async {
        await verifyLayout(width: 320, height: 568, size: .accessibility3, style: .dark)
    }

    func test_regular_screen_supports_light_appearance_and_signed_range_inputs() async {
        await verifyLayout(width: 430, height: 932, size: .large, style: .light)
    }

    private func verifyLayout(width: CGFloat, height: CGFloat, size: DynamicTypeSize, style: UIUserInterfaceStyle) async {
        let model = MoveListViewModel(moveRepository: FilterLayoutRepository())
        model.filterCondition.startupRange = 13...15
        model.filterCondition.guardRange = -14...(-10)
        let filter = FilterView(moveListViewModel: model, characterID: "fixture", analytics: RecordingAnalyticsClient())
            .environment(\.dynamicTypeSize, size)
        let controller = UIHostingController(rootView: filter)
        controller.overrideUserInterfaceStyle = style
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: height))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        for _ in 0..<10 {
            controller.view.layoutIfNeeded()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let scrolls = descendants(of: controller.view).compactMap { $0 as? UIScrollView }
        XCTAssertFalse(scrolls.isEmpty)
        for scroll in scrolls {
            XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1)
        }
        let fields = descendants(of: controller.view).compactMap { $0 as? UITextField }
        XCTAssertEqual(fields.count, 4)
        for field in fields {
            let frame = field.convert(field.bounds, to: controller.view)
            XCTAssertGreaterThanOrEqual(frame.minX, 0)
            XCTAssertLessThanOrEqual(frame.maxX, width)
            XCTAssertGreaterThan(field.bounds.width, 35)
            XCTAssertTrue(field.bounds.height.isFinite)
        }
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "Frame-filter-\(Int(width))-\(size)-\(style.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}

private struct FilterLayoutRepository: MoveRepository {
    func fetchMoves(characterName name: String) async throws -> [Move] { [] }
}
