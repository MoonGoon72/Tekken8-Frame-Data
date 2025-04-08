//
//  CharacterListView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 3/27/25.
//

import UIKit

final class CharacterListView: UIView {
    
    // MARK: Subviews
    
    let characterCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.itemSize = .init(width: UIScreen.main.bounds.width - 32, height: 80)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: CharacterCell.reuseIdentifier)
        return collectionView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupSubViews()
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupSubViews()
        setupLayout()
    }
    
    func setupSubViews() {
        addSubview(characterCollectionView)
    }
    
    func setupLayout() {
        setupCollectionViewLayouts()
    }
}

private extension CharacterListView {
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
