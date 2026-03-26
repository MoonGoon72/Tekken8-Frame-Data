//
//  MemoSectionHeaderView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoSectionHeaderView: UICollectionReusableView, ReuseIdentifiable {
    private let iconView = UIImageView()
    private let titleLabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(section: MemoSection) {
        switch section {
        case .pinned:
            let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            iconView.image = UIImage(systemName: "pin.fill", withConfiguration: config)
            iconView.tintColor = UIColor(red: 0.98, green: 0.78, blue: 0.46, alpha: 0.7)
            titleLabel.text = "고정됨".localized()
            titleLabel.textColor = UIColor(red: 0.98, green: 0.78, blue: 0.46, alpha: 0.7)
        case .general:
            iconView.image = nil
            titleLabel.text = "메모".localized()
            titleLabel.textColor = UIColor.white.withAlphaComponent(0.3)
        }
    }

    private func setupSubviews() {
        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
        ])
    }
}
