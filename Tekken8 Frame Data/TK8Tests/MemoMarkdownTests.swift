@testable import TK8
import UIKit
import XCTest

final class MemoMarkdownTests: XCTestCase {
    @MainActor
    func test_readingBodyDisplaysSequentialNumbersFromTheFirstListMarker() throws {
        let memo = Memo(
            id: UUID(), characterName: "common", title: "# Title",
            body: "# Title\n  3) First\n  1) Second",
            isPinned: false, updatedAt: Date()
        )
        let view = MemoComposeView()
        view.configure(memo: memo)
        view.setEditing(false)

        XCTAssertEqual(view.titleField.text, "# Title")
        XCTAssertEqual(try readingBody(in: view).text, "3. First\n4. Second")
    }

    @MainActor
    func test_readingBodyAppliesHeadingEmphasisQuoteAndCodeStyles() throws {
        let source = "  ## Punishes ##\n- **Guaranteed** then _sometimes_\n> Stay close\nUse `d/f+2`."
        let view = makeView(source: source)
        let text = try XCTUnwrap(readingBody(in: view).attributedText)

        XCTAssertEqual(text.string, "Punishes\n• Guaranteed then sometimes\n▎ Stay close\nUse d/f+2.")
        XCTAssertGreaterThan(try font(for: "Punishes", in: text).pointSize, try font(for: "Use", in: text).pointSize)
        XCTAssertTrue(try font(for: "Guaranteed", in: text).fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(try font(for: "sometimes", in: text).fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertTrue(try font(for: "d/f+2", in: text).fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
        XCTAssertEqual(Array(view.bodyField.text.utf8), Array(source.utf8))
    }

    @MainActor
    func test_unsupportedLinksImagesAndTablesRemainPlainText() throws {
        let source = """
        [**Guide**](https://example.com/a_(b))
        ![Move](https://example.com/move.png)
        <https://example.com>
        | Move | Frames |
        | --- | --- |
        | 1 | i10 |
        """
        let body = try readingBody(in: makeView(source: source))
        XCTAssertEqual(body.text, source)
        XCTAssertTrue(body.dataDetectorTypes.isEmpty)
        body.attributedText.enumerateAttributes(in: NSRange(location: 0, length: body.attributedText.length)) { attributes, _, _ in
            XCTAssertNil(attributes[.link])
            XCTAssertNil(attributes[.attachment])
        }
    }

    @MainActor
    func test_supportedMarkupStillRendersNextToUnsupportedSyntax() throws {
        let source = "[Site](https://example.com/a_(b)) **Important** [empty]() ~~strike~~ `[raw](url)`"
        let text = try XCTUnwrap(readingBody(in: makeView(source: source)).attributedText)

        XCTAssertEqual(text.string, "[Site](https://example.com/a_(b)) Important [empty]() ~~strike~~ [raw](url)")
        XCTAssertTrue(try font(for: "Important", in: text).fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertTrue(try font(for: "[raw](url)", in: text).fontDescriptor.symbolicTraits.contains(.traitMonoSpace))
    }

    @MainActor
    func test_readingBodyWrapsInsideNarrowDarkAccessibilityLayout() throws {
        let source = "## Notes\n5. A long punish description wraps below the number while reading with a large accessibility font."
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.keyWindow
        let window = UIWindow(windowScene: scene)
        let host = UIViewController()
        window.rootViewController = host
        host.traitOverrides.preferredContentSizeCategory = .large
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKey()
        }

        let view = makeView(source: source)
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        host.view.addSubview(view)
        window.layoutIfNeeded()
        view.layoutIfNeeded()
        let headingBefore = try font(for: "Notes", in: readingBody(in: view).attributedText)

        host.traitOverrides.userInterfaceStyle = .dark
        host.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        host.view.setNeedsLayout()
        window.layoutIfNeeded()
        view.layoutIfNeeded()

        let body = try readingBody(in: view)
        let text = try XCTUnwrap(body.attributedText)
        let headingAfter = try font(for: "Notes", in: text)
        let listFont = try font(for: "A long", in: text)
        let listLocation = (text.string as NSString).range(of: "5.").location
        let paragraph = try XCTUnwrap(text.attribute(.paragraphStyle, at: listLocation, effectiveRange: nil) as? NSParagraphStyle)
        let foreground = try XCTUnwrap(text.attribute(.foregroundColor, at: listLocation, effectiveRange: nil) as? UIColor)

        XCTAssertGreaterThan(headingAfter.pointSize, headingBefore.pointSize)
        XCTAssertEqual(view.traitCollection.userInterfaceStyle, .dark)
        XCTAssertEqual(foreground.resolvedColor(with: view.traitCollection), UIColor.tkPrimaryText.resolvedColor(with: view.traitCollection))
        XCTAssertGreaterThan(paragraph.headIndent, 0)
        XCTAssertEqual(body.bounds.width, 280, accuracy: 0.5)
        let fitted = body.sizeThatFits(CGSize(width: body.bounds.width, height: .greatestFiniteMagnitude))
        XCTAssertLessThanOrEqual(fitted.width, body.bounds.width)
        XCTAssertGreaterThan(fitted.height, headingAfter.lineHeight + listFont.lineHeight)
    }

    @MainActor
    func test_latestMarkdownBackupUsesTheSameReadingAndEditingContent() throws {
        let codec = MemoBackupCodec()
        let repository = DefaultMemoRepository(coreDataManager: InMemoryCoreDataManager())
        let viewModel = MemoViewModel(memoRepository: repository)
        let title = "**Literal title**"
        let source = "## Wall punish\r\n1. **Confirm**\r\n> Use `d/f+2`.\r\n"
        let current = Memo(
            id: UUID(), characterName: "common", title: title, body: title + "\r\n" + source,
            isPinned: false, updatedAt: Date(timeIntervalSince1970: 200)
        )
        var older = current
        older.body = title + "\nOld text"
        older.updatedAt = Date(timeIntervalSince1970: 100)

        _ = try viewModel.importMemos(from: codec.encode(memos: [older]))
        let result = try viewModel.importMemos(from: codec.encode(memos: [current]))
        let restored = try XCTUnwrap(viewModel.memos.first)

        XCTAssertEqual(result, MemoImportResult(insertedCount: 0, updatedCount: 1, skippedCount: 0))
        XCTAssertEqual(viewModel.memos.count, 1)
        XCTAssertEqual(restored.id, current.id)
        XCTAssertEqual(restored.updatedAt, current.updatedAt)
        let localView = MemoComposeView()
        localView.configure(memo: current)
        localView.setEditing(false)
        let restoredView = MemoComposeView()
        restoredView.configure(memo: restored)
        restoredView.setEditing(false)
        XCTAssertEqual(try readingBody(in: restoredView).attributedText, try readingBody(in: localView).attributedText)
        XCTAssertEqual(restoredView.titleField.text, title)
        restoredView.setEditing(true)
        XCTAssertEqual(Array(restoredView.bodyField.text.utf8), Array(source.utf8))
        let exported = try codec.decodeMemos(from: viewModel.exportMemos().data)
        XCTAssertEqual(exported.map { Array($0.body.utf8) }, [Array(current.body.utf8)])
    }

    @MainActor
    private func makeView(source: String) -> MemoComposeView {
        let view = MemoComposeView()
        view.configure(memo: Memo(
            id: UUID(), characterName: "common", title: "# Title", body: "# Title\n" + source,
            isPinned: false, updatedAt: Date()
        ))
        view.setEditing(false)
        return view
    }

    private func font(for word: String, in text: NSAttributedString) throws -> UIFont {
        let range = (text.string as NSString).range(of: word)
        let location = try XCTUnwrap(range.location == NSNotFound ? nil : range.location, "Expected \(word) in rendered text")
        return try XCTUnwrap(text.attribute(.font, at: location, effectiveRange: nil) as? UIFont)
    }

    @MainActor
    private func readingBody(in view: MemoComposeView) throws -> UITextView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? UITextView }
            .first { !$0.isHidden && $0 !== view.titleField })
    }
}
