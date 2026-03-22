//
//  MemoCollectionViewCell.swift
//  TK8
//

import Combine
import Foundation
import UIKit

final class MemoCollectionViewCell: UICollectionViewCell, ReuseIdentifiable {

    // MARK: Regarding editing

    private(set) var isEditingMode = false
    private let checkmarkContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()
    private let checkmarkImage: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        let image = UIImage(systemName: "circle", withConfiguration: config)
        let view = UIImageView(image: image)
        view.tintColor = .white.withAlphaComponent(0.3)
        view.contentMode = .center
        return view
    }()

    // MARK: SubViews
    private let wrapperView = UIView()

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

    private var checkmarkWidthConstraint: NSLayoutConstraint!

    override var isSelected: Bool {
        didSet {
            guard isEditingMode else { return }
            updateCheckmarkAppearance(animated: true)
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupSubViews()
        setupSubViewLayouts()
        setupStyles()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func configure(memo: Memo, image: UIImage?) {
        iconView.image = image ?? UIImage(named: "mokujin")
        title.text = memo.title
        body.text = memo.body.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
        updatedAt.text = memo.updatedAt.formatted(date: .abbreviated, time: .omitted)
    }

    func setEditing(_ editing: Bool, animated: Bool) {
        guard isEditingMode != editing else { return }
        isEditingMode = editing

        if editing {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
            self.checkmarkImage.image = UIImage(systemName: "circle", withConfiguration: config)
            self.checkmarkImage.tintColor = .white.withAlphaComponent(0.3)
        }

        let actions = {
            self.checkmarkWidthConstraint.constant = editing ? 34 : 0
            self.contentView.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: actions)
        } else {
            actions()
        }

        if !editing {
            updateCheckmarkAppearance(animated: false)
        }
    }

    private func updateCheckmarkAppearance(animated: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)

        let actions = {
            if self.isSelected {
                self.checkmarkImage.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
                self.checkmarkImage.tintColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1)
                // 셀 tint
                self.contentView.backgroundColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.12)
                self.contentView.layer.borderColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 0.25).cgColor
                // Teal 채우기 + 체크 아이콘 표시
//                self.checkmarkView.backgroundColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1)
//                self.checkmarkView.layer.borderColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1).cgColor
//                self.checkmarkImage.alpha = 1
            } else {
                // 빈 원
                self.checkmarkImage.image = UIImage(systemName: "circle", withConfiguration: config)
                self.checkmarkImage.tintColor = UIColor.white.withAlphaComponent(0.3)
                // 기본 glass
                self.contentView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
                self.contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            }
        }

        if animated {
            UIView.transition(with: checkmarkImage, duration: 0.2, options: .transitionCrossDissolve, animations: actions)
        } else {
            actions()
        }
    }

    private func setupStyles() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        contentView.layer.cornerRadius = 14
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        contentView.clipsToBounds = true
    }

    private func setupSubViews() {
        contentView.addSubview(checkmarkContainer)
        checkmarkContainer.addSubview(checkmarkImage)

        contentView.addSubview(wrapperView)
        wrapperView.addSubview(iconView)
        wrapperView.addSubview(contentStackView)
        wrapperView.addSubview(updatedAt)

        contentStackView.addArrangedSubview(title)
        contentStackView.addArrangedSubview(body)
    }

    private func setupSubViewLayouts() {
        checkmarkContainer.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImage.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        updatedAt.translatesAutoresizingMaskIntoConstraints = false

        checkmarkWidthConstraint = checkmarkContainer.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            // CheckmarkContainer: 좌측, 세로 꽉 참
            checkmarkContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            checkmarkContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            checkmarkContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            checkmarkWidthConstraint,

            // CheckmarkImage: 컨테이너 중앙
            checkmarkImage.centerXAnchor.constraint(equalTo: checkmarkContainer.centerXAnchor),
            checkmarkImage.centerYAnchor.constraint(equalTo: checkmarkContainer.centerYAnchor),

            // WrapperView: checkmarkContainer 우측부터 끝
            wrapperView.leadingAnchor.constraint(equalTo: checkmarkContainer.trailingAnchor),
            wrapperView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            wrapperView.topAnchor.constraint(equalTo: contentView.topAnchor),
            wrapperView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            // Icon
            iconView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 44),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            // UpdateAt
            updatedAt.topAnchor.constraint(equalTo: wrapperView.topAnchor, constant: 14),
            updatedAt.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor, constant: -16),

            // Content Stack
            contentStackView.centerYAnchor.constraint(equalTo: wrapperView.centerYAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            contentStackView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor, constant: -8),
        ])
    }
}
