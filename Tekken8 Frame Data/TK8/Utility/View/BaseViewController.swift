//
//  BaseViewController.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import Combine
import UIKit

class BaseViewController: UIViewController {

    var subscriptionSet: Set<AnyCancellable>

    // MARK: Initializer
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        subscriptionSet = []
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    required init?(coder: NSCoder) {
        subscriptionSet = []
        super.init(coder: coder)
    }
    
    // MARK: ViewController's lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupDelegation()
        setupDataSource()
        configureKeyboardDismissOnTap()
        bindViewModel()
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupNavigationBar()
        setupSubscription()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationItem.hidesSearchBarWhenScrolling = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        subscriptionSet.removeAll()
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
