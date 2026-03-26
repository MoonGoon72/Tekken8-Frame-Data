//
//  SettingTableView.swift
//  TK8
//

import Foundation
import UIKit

final class SettingTableView: BaseView {
    
    // MARK: Subviews
    
    let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.isScrollEnabled = false
        tableView.alwaysBounceVertical = false
        return tableView
    }()
    
    // MARK: SettingTableView's lifecycle
    
    override func setupSubviews() {
        super.setupSubviews()
        
        addSubview(tableView)
    }
    
    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        
        setupTableViewLayouts()
    }
    
    override func setupStyles() {
        super.setupStyles()
        
        tableView.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tableView.layer.cornerRadius = 14
        tableView.clipsToBounds = true
    }
    
    // MARK: Custom methods
    
    func setTableViewDelegate(_ delegate: UITableViewDelegate) {
        tableView.delegate = delegate
    }
    
    func setTableViewDataSource(_ dataSource: UITableViewDataSource) {
        tableView.dataSource = dataSource
    }
    
    func register(_ cellClass: AnyClass?, forCellReuseIdentifier identifier: String) {
        tableView.register(cellClass, forCellReuseIdentifier: identifier)
    }
    
    // MARK: Private setup methods
    
    private func setupTableViewLayouts() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}
