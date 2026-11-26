import UIKit

enum MemoMarkdownRenderer {
    static func render(_ source: String, traits: UITraitCollection) -> NSAttributedString {
        let output = NSMutableAttributedString()
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        let bodyFont = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traits)
        let headingFont = UIFontMetrics(forTextStyle: .headline)
            .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold), compatibleWith: traits)
        for (index, line) in lines.enumerated() {
            let heading = line.prefix { $0 == "#" }
            let text: String
            let font: UIFont
            if (1...6).contains(heading.count), line.dropFirst(heading.count).first?.isWhitespace == true {
                text = String(line.dropFirst(heading.count).drop(while: { $0.isWhitespace }))
                font = headingFont
            } else if let marker = line.first, "-+*".contains(marker), line.dropFirst().first?.isWhitespace == true {
                text = "• " + line.dropFirst().drop(while: { $0.isWhitespace })
                font = bodyFont
            } else {
                text = line
                font = bodyFont
            }
            output.append(NSAttributedString(
                string: text + (index < lines.count - 1 ? "\n" : ""),
                attributes: [.font: font, .foregroundColor: UIColor.tkPrimaryText]
            ))
        }
        return output
    }
}
