//
//  MemoCollectionViewCell.swift
//  TK8
//

import Foundation
import UIKit

final class MemoCollectionViewCell: UICollectionViewCell, ReuseIdentifiable {
    private let iconView: UIImageView = {
        let view = UIImageView()
        view.sizeToFit()
        return view
    }()
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    
    private let title: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        return label
    }()
    private let body: UILabel = {
        let label = UILabel()
        label.numberOfLines = 1
        return label
    }()
    private let updatedAt: UILabel = {
        let label = UILabel()
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
        body.text = memo.body
        updatedAt.text = memo.updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func setupStyles() {
        contentView.backgroundColor = .tkRed
        contentView.layer.cornerRadius = 5
    }

    private func setupSubViews() {
        contentView.addSubview(iconView)
        contentView.addSubview(contentStackView)

        contentStackView.addArrangedSubview(title)
        contentStackView.addArrangedSubview(body)
        contentStackView.addArrangedSubview(updatedAt)
    }

    private func setupSubViewLayouts() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        updatedAt.translatesAutoresizingMaskIntoConstraints = false

        updatedAt.font = .systemFont(ofSize: 14)
        updatedAt.textAlignment = .right
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            contentStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            contentStackView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            contentStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            updatedAt.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor)
        ])
    }
}
