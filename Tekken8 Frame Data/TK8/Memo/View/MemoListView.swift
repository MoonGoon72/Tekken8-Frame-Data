//
//  MemoListView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoListView: BaseView {

    // MARK: SubView

    let collectionView: UICollectionView = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(0.1)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 8, bottom: 16, trailing: 8)
        section.interGroupSpacing = 10

        // Header
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(32))
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        let layout = UICollectionViewCompositionalLayout(section: section)
        let collectionView = UICollectionView(frame: .infinite, collectionViewLayout: layout)
        collectionView.register(
            MemoCollectionViewCell.self,
            forCellWithReuseIdentifier: MemoCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            MemoSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: MemoSectionHeaderView.reuseIdentifier
        )
        return collectionView
    }()

    override func setupSubviews() {
        super.setupSubviews()
        addSubview(collectionView)
    }

    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        setupCollecionViewLayout()
    }

    override func setupStyles() {
        super.setupStyles()
        collectionView.backgroundColor = .tkBackground
    }

    // MARK: Custom methods

    func collecionViewDelegate(_ delegate: UICollectionViewDelegate) {
        collectionView.delegate = delegate
    }
}

private extension MemoListView {
    func setupCollecionViewLayout() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: self.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        ])
    }
}
