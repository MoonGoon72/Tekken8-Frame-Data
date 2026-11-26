import UIKit

enum MemoMarkdownRenderer {
    private static let inlineOptions = AttributedString.MarkdownParsingOptions(
        interpretedSyntax: .inlineOnlyPreservingWhitespace
    )

    private static let verbatimSpans: NSRegularExpression? = {
        // Match code first so a link written inside backticks is rendered as code.
        let code = #"(`+)(?!`).*?(?<!`)\1(?!`)"#
        let label = #"(?:\\.|[^\[\]\\]|\[(?:\\.|[^\[\]\\])*\])*"#
        let destination = #"(?:\\.|[^()\\]|\((?:\\.|[^()\\])*\))*"#
        let linkOrImage = #"(?<!\\)!?\["# + label + #"\]\("# + destination + #"\)"#
        let autolink = #"<(?:[a-zA-Z][a-zA-Z0-9+.-]*:|[^<>\s@]+@)[^<>\s]+>"#
        let strike = #"(?<!\\)~~(?=\S).*?(?<=\S)~~"#
        return try? NSRegularExpression(
            pattern: [code, linkOrImage, autolink, strike].joined(separator: "|"),
            options: .dotMatchesLineSeparators
        )
    }()

    static func render(_ source: String, traits: UITraitCollection) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        let bodyFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let headingFont = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold), compatibleWith: traits)
        var orderedList: (separator: Swift.Character, nextNumber: Int)?
        var openFence: Substring?
        var plainLines: [String] = []
        let plainAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.tkPrimaryText]

        func flushPlainParagraph(followedByLine: Bool) {
            guard !plainLines.isEmpty else { return }
            appendInline(plainLines.joined(separator: "\n"), font: bodyFont, attributes: plainAttributes, to: output)
            if followedByLine { output.append(NSAttributedString(string: "\n", attributes: plainAttributes)) }
            plainLines.removeAll(keepingCapacity: true)
        }

        for (index, line) in lines.enumerated() {
            let indentation = line.prefix { $0 == " " }.count
            let block = indentation < 4 ? line.dropFirst(indentation) : line[...]
            let fence = block.prefix { $0 == block.first && ($0 == "`" || $0 == "~") }
            let afterFence = block.dropFirst(fence.count)
            let opensFence = fence.count >= 3 && (fence.first != "`" || !afterFence.contains("`"))
            if openFence != nil || opensFence {
                flushPlainParagraph(followedByLine: true)
                output.append(NSAttributedString(
                    string: line + (index < lines.count - 1 ? "\n" : ""), attributes: plainAttributes
                ))
                orderedList = nil
                if let opened = openFence {
                    if fence.hasPrefix(opened) && afterFence.allSatisfy(\.isWhitespace) { openFence = nil }
                } else {
                    openFence = fence
                }
                continue
            }
            let digits = block.prefix { ("0"..."9").contains($0) }
            let afterDigits = block.dropFirst(digits.count)
            let blockText: String
            let marker: String
            let font: UIFont

            if (1...9).contains(digits.count), let number = Int(digits),
               let separator = afterDigits.first, ".)".contains(separator),
               afterDigits.dropFirst().first?.isWhitespace == true {
                let displayNumber = orderedList?.separator == separator ? orderedList?.nextNumber ?? number : number
                orderedList = (separator, displayNumber + 1)
                marker = "\(displayNumber). "
                blockText = String(afterDigits.dropFirst().drop(while: { $0.isWhitespace }))
                font = bodyFont
            } else {
                orderedList = nil
                let heading = block.prefix { $0 == "#" }
                if (1...6).contains(heading.count), block.dropFirst(heading.count).first?.isWhitespace == true {
                    let content = block.dropFirst(heading.count).trimmingCharacters(in: .whitespaces)
                    blockText = content.replacingOccurrences(of: #"\s+#+$"#, with: "", options: .regularExpression)
                    marker = ""
                    font = headingFont
                } else if let bullet = block.first, "-+*".contains(bullet),
                          block.dropFirst().first?.isWhitespace == true {
                    blockText = String(block.dropFirst().drop(while: { $0.isWhitespace }))
                    marker = "• "
                    font = bodyFont
                } else if block.first == ">" {
                    blockText = String(block.dropFirst().drop(while: { $0.isWhitespace }))
                    marker = "▎ "
                    font = bodyFont
                } else if !line.allSatisfy(\.isWhitespace) {
                    plainLines.append(line)
                    continue
                } else {
                    blockText = line
                    marker = ""
                    font = bodyFont
                }
            }

            flushPlainParagraph(followedByLine: true)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byWordWrapping
            paragraph.headIndent = (marker as NSString).size(withAttributes: [.font: font]).width
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.tkPrimaryText,
                .paragraphStyle: paragraph
            ]
            output.append(NSAttributedString(string: marker, attributes: attributes))
            appendInline(blockText, font: font, attributes: attributes, to: output)
            if index < lines.count - 1 {
                output.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        }
        flushPlainParagraph(followedByLine: false)
        return output
    }

    private static func appendInline(
        _ source: String,
        font: UIFont,
        attributes: [NSAttributedString.Key: Any],
        to output: NSMutableAttributedString
    ) {
        let text = source as NSString
        let spans = verbatimSpans?.matches(in: source, range: NSRange(location: 0, length: text.length)) ?? []
        let literals = spans.filter { $0.range(at: 1).location == NSNotFound }
            .map { (range: $0.range, text: text.substring(with: $0.range)) }

        // Opaque text lets emphasis enclose a literal span without interpreting its contents.
        let marker = "\u{F0000}"
        var token = marker
        while source.contains(token) { token += marker }
        let maskedSource = NSMutableString(string: source)
        for literal in literals.reversed() {
            maskedSource.replaceCharacters(in: literal.range, with: token)
        }

        let masked = maskedSource as String
        let mayContainExplicitLink = masked.contains("[") || masked.contains("<")
        guard let formatted = try? AttributedString(markdown: masked, options: inlineOptions),
              !formatted.runs.contains(where: { run in
                  run.imageURL != nil || (mayContainExplicitLink && run.link != nil) ||
                      run.inlinePresentationIntent?.contains(.strikethrough) == true
              }) else {
            // Keep the source visible when Foundation consumes unsupported Markdown syntax.
            output.append(NSAttributedString(string: source, attributes: attributes))
            return
        }

        var restored = literals.makeIterator()
        for run in formatted.runs {
            var runAttributes = attributes
            let intent = run.inlinePresentationIntent ?? []
            let isCode = intent.contains(.code)
            let baseFont = isCode ? UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular) : font
            var fontTraits = baseFont.fontDescriptor.symbolicTraits
            if intent.contains(.stronglyEmphasized) { fontTraits.insert(.traitBold) }
            if intent.contains(.emphasized) { fontTraits.insert(.traitItalic) }
            if fontTraits != baseFont.fontDescriptor.symbolicTraits,
               let descriptor = baseFont.fontDescriptor.withSymbolicTraits(fontTraits) {
                runAttributes[.font] = UIFont(descriptor: descriptor, size: baseFont.pointSize)
            } else {
                runAttributes[.font] = baseFont
            }
            if isCode { runAttributes[.backgroundColor] = UIColor.tkMutedSurface }
            let pieces = String(formatted.characters[run.range]).components(separatedBy: token)
            for (index, piece) in pieces.enumerated() {
                if index > 0, let literal = restored.next() {
                    output.append(NSAttributedString(string: literal.text, attributes: runAttributes))
                }
                output.append(NSAttributedString(string: piece, attributes: runAttributes))
            }
        }
    }
}
