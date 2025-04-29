//
//  MoveSectionHeaderView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/29/25.
//

import UIKit

final class MoveSectionHeaderView: UICollectionReusableView, ReuseIdentifiable {
    let containerView = UIView()
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupContainer()
        setupTitleLabel()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupTitleLabel() {
        containerView.addSubview(titleLabel)
        titleLabel.font = .boldSystemFont(ofSize: 18)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupContainer() {
        addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .tkRed
        containerView.layer.cornerRadius = 8
        containerView.layer.masksToBounds = true
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            containerView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }
}
