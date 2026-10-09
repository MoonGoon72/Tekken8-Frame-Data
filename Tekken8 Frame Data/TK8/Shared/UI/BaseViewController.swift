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
    var bannerAdHost: BannerAdHost?

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
        bannerAdHost?.install(in: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupNavigationBar()
        setupSubscription()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationItem.hidesSearchBarWhenScrolling = true
        bannerAdHost?.appear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        bannerAdHost?.disappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bannerAdHost?.layout()
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        bannerAdHost?.setEditing(editing)
    }

    deinit {
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
