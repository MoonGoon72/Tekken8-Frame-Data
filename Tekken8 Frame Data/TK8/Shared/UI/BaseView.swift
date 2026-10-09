//
//  BaseView.swift
//  Tekken8 Frame Data
//
//  Created by 문영균 on 4/13/25.
//

import UIKit

class BaseView: UIView {
    
    // MARK: Initializer
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupStyles()
        setupSubviews()
        setupSubviewLayouts()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        setupStyles()
        setupSubviews()
        setupSubviewLayouts()
    }
    
    // MARK: BaseView's lifecycle
    
    func setupStyles() {}
    
    func setupSubviews() {}
    
    func setupSubviewLayouts() {}
    
}
