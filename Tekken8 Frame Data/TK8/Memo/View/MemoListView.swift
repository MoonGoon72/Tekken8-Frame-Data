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
            heightDimension: .fractionalHeight(0.2)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(44)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)
        let collectionView = UICollectionView(frame: .infinite, collectionViewLayout: layout)
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
