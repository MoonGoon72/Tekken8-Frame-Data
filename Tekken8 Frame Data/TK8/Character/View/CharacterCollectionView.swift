//
//  CharacterCollectionView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/27/25.
//

import UIKit

enum CharacterCollectionViewMode: String, Codable {
    case list
    case grid
}

final class CharacterCollectionView: BaseView {

    // MARK: Subviews

    let characterCollectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: CharacterCollectionView.makeLayout(for: .list))

        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Constants.characterHostingCell)
        return collectionView
    }()

    // MARK: CharacterCollectionView's lifecycle

    override func setupSubviews() {
        super.setupSubviews()

        addSubview(characterCollectionView)
    }

    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()

        setupCollectionViewLayouts()
    }

    override func setupStyles() {
        super.setupStyles()

        characterCollectionView.backgroundColor = .tkBackground
    }

    // MARK: Custom method

    func setCollectionViewDelegate(_ delegate: UICollectionViewDelegate) {
        characterCollectionView.delegate = delegate
    }

    func applyViewMode(_ viewMode: CharacterCollectionViewMode, animated: Bool = true) {
        let layout = Self.makeLayout(for: viewMode)
        characterCollectionView.setCollectionViewLayout(layout, animated: animated)
    }

    private static func makeLayout(for viewMode: CharacterCollectionViewMode) -> UICollectionViewCompositionalLayout {
        switch viewMode {
        case .list:
            return makeListLayout()
        case .grid:
            return makeGridLayout()
        }
    }

    private static func makeListLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(100)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(100)
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: groupSize,
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 8,
                bottom: 0,
                trailing: 8
            )
            return section
        }
    }

    private static func makeGridLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout {
            _,
            environment in
            let horizontalInset: CGFloat = 12
            let itemSpacing: CGFloat = 8
            let minimumThreeColumnWidth: CGFloat = 120
            let nameAreaHeight: CGFloat = 40

            let contentWidth = environment.container.effectiveContentSize.width - (horizontalInset * 2)
            let threeColumnWidth = (contentWidth - (itemSpacing * 2)) / 3
            let columnCount = threeColumnWidth >= minimumThreeColumnWidth ? 3 : 2

            let cellWidth = floor(
                (contentWidth - (itemSpacing * CGFloat(columnCount - 1))) / CGFloat(columnCount)
            )
            let cellHeight = cellWidth + nameAreaHeight

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columnCount
            )
            group.interItemSpacing = .fixed(itemSpacing)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = itemSpacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 8,
                leading: horizontalInset,
                bottom: 8,
                trailing: horizontalInset
            )
            return section
        }
    }
}

private enum Constants {
    static let characterHostingCell = "characterHostingCell"
}

private extension CharacterCollectionView {
    func setupCollectionViewLayouts() {
        characterCollectionView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            characterCollectionView.topAnchor.constraint(equalTo: self.topAnchor),
            characterCollectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            characterCollectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            characterCollectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
}
