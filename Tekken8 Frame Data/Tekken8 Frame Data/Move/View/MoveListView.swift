//
//  MoveListView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/8/25.
//

import UIKit

final class MoveListView: BaseView {
    
    // MARK: Subviews
    
    let moveCollectionView: UICollectionView = {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        let layout = UICollectionViewCompositionalLayout(section: section)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: MoveCell.reuseIdentifier)
        return collectionView
    }()
    
    // MARK: MoveCollectionView's lifecycle
    
    override func setupSubviews() {
        super.setupSubviews()
        
        addSubview(moveCollectionView)
    }
    
    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        
        setupCollectionViewLayouts()
    }
    
    // MARK: Custom Method
    
    func setCollectionViewDelegate(_ delegate: UICollectionViewDelegate) {
        moveCollectionView.delegate = delegate
    }
}

private extension MoveListView {
    func setupCollectionViewLayouts() {
        moveCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            moveCollectionView.topAnchor.constraint(equalTo: self.topAnchor),
            moveCollectionView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            moveCollectionView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            moveCollectionView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}
