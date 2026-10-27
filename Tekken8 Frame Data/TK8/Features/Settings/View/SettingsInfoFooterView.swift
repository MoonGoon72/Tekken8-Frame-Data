import UIKit

final class SettingsInfoFooterView: UIView {
    init(appVersion: String, dataVersion: String?) {
        super.init(frame: .zero)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 5
        let brand = label("TK8", style: .headline)
        brand.textColor = .tkPrimaryText
        stack.addArrangedSubview(brand)
        stack.setCustomSpacing(12, after: brand)
        stack.addArrangedSubview(label(String(format: "App version %@".localized(), appVersion)))
        if let dataVersion {
            stack.addArrangedSubview(label(String(format: "Tekken data %@".localized(), dataVersion)))
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, style: UIFont.TextStyle = .caption1) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .tkSecondaryText
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }
}
