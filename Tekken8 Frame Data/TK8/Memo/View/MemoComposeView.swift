//
//  MemoComposeView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoComposeView: BaseView {
    private let bodyTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 20)
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
        bodyTextView.becomeFirstResponder()
    }
}

private extension MemoComposeView {
    func setupConstraints() {
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            bodyTextView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            bodyTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10),
            bodyTextView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 10),
            bodyTextView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
    }
}
