//
//  MemoCollectionViewCell.swift
//  TK8
//

import Foundation
import UIKit

final class MemoCollectionViewCell: UICollectionViewCell, ReuseIdentifiable {
    private let iconView: UIImageView = {
        let view = UIImageView()
        return view
    }()
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        return stackView
    }()
    private let detailStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        return stackView
    }()
    private let title: UILabel = {
        let label = UILabel()
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

        setupSubViewLayouts()
        setupSubViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(memo: Memo) {
        // TODO: 이미지 넣기
        title.text = memo.title
        body.text = memo.body
        updatedAt.text = memo.updatedAt.description
    }

    private func setupSubViews() {
        contentStackView.addArrangedSubview(title)
        contentStackView.addArrangedSubview(detailStackView)

        detailStackView.addArrangedSubview(body)
        detailStackView.addArrangedSubview(updatedAt)
    }

    private func setupSubViewLayouts() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        detailStackView.translatesAutoresizingMaskIntoConstraints = false
        title.translatesAutoresizingMaskIntoConstraints = false
        body.translatesAutoresizingMaskIntoConstraints = false
        updatedAt.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            title.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
            detailStackView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor)
        ])
    }
}
