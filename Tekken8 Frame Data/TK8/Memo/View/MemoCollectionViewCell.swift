//
//  MemoCollectionViewCell.swift
//  TK8
//

import Foundation
import UIKit

final class MemoCollectionViewCell: UICollectionViewCell, ReuseIdentifiable {
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 12
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return view
    }()
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 3
        return stackView
    }()
    
    private let title: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        return label
    }()
    private let body: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        label.font = .systemFont(ofSize: 13)
        label.textColor = UIColor.white.withAlphaComponent(0.5)
        return label
    }()
    private let updatedAt: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = UIColor.white.withAlphaComponent(0.35)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubViews()
        setupSubViewLayouts()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(memo: Memo) {
        // TODO: 이미지 넣기
        iconView.image = UIImage(named: "mokujin")
        title.text = memo.title
        body.text = memo.body.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
        updatedAt.text = memo.updatedAt.formatted(date: .abbreviated, time: .omitted)
    }

    private func setupStyles() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        contentView.layer.cornerRadius = 14
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        contentView.clipsToBounds = true
    }

    private func setupSubViews() {
        contentView.addSubview(iconView)
        contentView.addSubview(contentStackView)
        contentView.addSubview(updatedAt)

        contentStackView.addArrangedSubview(title)
        contentStackView.addArrangedSubview(body)
    }

    private func setupSubViewLayouts() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        updatedAt.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            updatedAt.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            updatedAt.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -16),

            contentStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
    }
}
