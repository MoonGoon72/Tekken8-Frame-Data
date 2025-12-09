//
//  MemoView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoView: BaseView {

    // MARK: Subviews

    let memoView: UIView = {
        let view = UIView()
        view.backgroundColor = .tkBackground

        return view
    }()

    override func setupSubviews() {
        super.setupSubviews()

        addSubview(memoView)
    }

    override func setupStyles() {
        super.setupStyles()

        memoView.backgroundColor = .tkBackground
    }

    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        
        setupMemoViewLayouts()
    }
}

private extension MemoView {
    func setupMemoViewLayouts() {
        memoView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            memoView.topAnchor.constraint(equalTo: self.topAnchor),
            memoView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            memoView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            memoView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
        ])
    }
}
