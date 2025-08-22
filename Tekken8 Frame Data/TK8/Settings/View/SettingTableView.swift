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
        
        tableView.backgroundColor = .tkBackground
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
            tableView.topAnchor.constraint(equalTo: self.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}
