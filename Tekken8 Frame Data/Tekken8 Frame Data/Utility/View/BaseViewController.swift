//
//  BaseViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import UIKit

class BaseViewController: UIViewController {
    
    // MARK: Initializer
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: ViewController's lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDelegation()
        setupDataSource()
        configureKeyboardDismissOnTap()
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupNavigationBar()
        setupSubscription()
    }
    
    // MARK: Tekken8 Frame Data lifecycle
    
    func setupDelegation() {}
    
    func setupDataSource() {}
    
    func setupNavigationBar() {}
    
    func setupSubscription() {}
    
    func bindViewModel() {}
    
    // MARK: Helper
    
    func configureKeyboardDismissOnTap() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(endEditing))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func endEditing() {
        view.endEditing(true)
    }
}
