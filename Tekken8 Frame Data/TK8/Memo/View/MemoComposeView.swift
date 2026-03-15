//
//  MemoComposeView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoComposeView: BaseView {
    private let bodyTextView: UITextView = {
        let textView = UITextView()
        return textView
    }()

    var content: String {
        return bodyTextView.text
    }

    override func setupStyles() {
        super.setupStyles()
        self.backgroundColor = .tkBackground
        bodyTextView.backgroundColor = .tkBackground
        bodyTextView.tintColor = .tkRed
    }

    override func setupSubviews() {
        super.setupSubviews()
        addSubview(bodyTextView)
    }

    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        setupConstraints()
    }

    func configure(memo: Memo?) {
        guard let memo else { return }
        bodyTextView.text = memo.body
    }

    func activateTextView() {
        becomeFirstResponder()
    }
}

private extension MemoComposeView {
    func setupConstraints() {
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bodyTextView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            bodyTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            bodyTextView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            bodyTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}
