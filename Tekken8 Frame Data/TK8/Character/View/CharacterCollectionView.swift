//
//  CharacterCollectionView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/27/25.
//

import UIKit

final class CharacterCollectionView: BaseView {
    
    // MARK: Subviews
    
    let characterCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = .init(width: UIScreen.main.bounds.width - 8, height: 100)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: CharacterCell.reuseIdentifier)
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
