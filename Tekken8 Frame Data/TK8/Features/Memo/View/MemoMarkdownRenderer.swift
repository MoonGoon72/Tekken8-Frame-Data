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
            let indentation = line.prefix { $0 == " " }.count
            let block = indentation < 4 ? line.dropFirst(indentation) : line[...]
            let heading = block.prefix { $0 == "#" }
            let text: String
            let font: UIFont
            if (1...6).contains(heading.count), block.dropFirst(heading.count).first?.isWhitespace == true {
                let content = block.dropFirst(heading.count).trimmingCharacters(in: .whitespaces)
                text = content.replacingOccurrences(of: #"\s+#+$"#, with: "", options: .regularExpression)
                font = headingFont
            } else if let marker = block.first, "-+*".contains(marker), block.dropFirst().first?.isWhitespace == true {
                text = "• " + block.dropFirst().drop(while: { $0.isWhitespace })
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
