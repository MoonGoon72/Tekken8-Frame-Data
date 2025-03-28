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
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = Texts.placeholder
        
        return searchBar
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
        addSubview(searchBar)
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
            searchBar.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 60),
            
            characterCollectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            characterCollectionView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            characterCollectionView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),
            characterCollectionView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

private extension CharacterListView {
    enum Texts {
        static let placeholder = "캐릭터 이름을 입력해주세요."
    }
}
