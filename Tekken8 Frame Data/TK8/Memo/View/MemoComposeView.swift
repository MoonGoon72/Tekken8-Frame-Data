//
//  MemoComposeView.swift
//  TK8
//

import Foundation
import UIKit

final class MemoComposeView: BaseView {

    // MARK: - Character chip

    private let characterChipButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.cornerStyle = .capsule
        config.baseForegroundColor = UIColor.white.withAlphaComponent(0.5)
        config.image = UIImage(
            systemName: "chevron.down",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        )
        config.imagePlacement = .trailing
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 10)
        config.background.backgroundColor = UIColor.white.withAlphaComponent(0.07)

        let button = UIButton(configuration: config)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        return button
    }()
    private let characterIconView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        return view
    }()
    private let characterRow = UIView()

    // MARK: - Text views

    private let titleTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 22, weight: .semibold)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }()
    private let titlePlaceholder: UILabel = {
        let label = UILabel()
        label.text = "제목".localized()
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.textColor = UIColor.white.withAlphaComponent(0.2)
        return label
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        return view
    }()

    private let bodyTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }()
    private let bodyPlaceholder: UILabel = {
        let label = UILabel()
        label.text = "작성할 메모를 입력하세요.".localized()
        label.font = .systemFont(ofSize: 16)
        label.textColor = UIColor.white.withAlphaComponent(0.15)
        return label
    }()

    // MARK: - Public

    var titleContent: String { titleTextView.text }
    var bodyContent: String { bodyTextView.text }

    var onCharacterChipTapped: (() -> Void)?

    override func setupStyles() {
        super.setupStyles()
        self.backgroundColor = .tkBackground
        titleTextView.tintColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1)
        bodyTextView.tintColor = UIColor(red: 0.36, green: 0.79, blue: 0.65, alpha: 1)
    }

    override func setupSubviews() {
        super.setupSubviews()
        addSubview(characterRow)
        characterRow.addSubview(characterIconView)
        characterRow.addSubview(characterChipButton)

        addSubview(titleTextView)
        addSubview(titlePlaceholder)
        addSubview(separator)
        addSubview(bodyTextView)
        addSubview(bodyPlaceholder)

        characterChipButton.addTarget(self, action: #selector(chipTapped), for: .touchUpInside)
    }

    override func setupSubviewLayouts() {
        super.setupSubviewLayouts()
        setupConstraints()
    }

    // MARK: - Configure

    func configure(memo: Memo?) {
        guard let memo else { return }
        titleTextView.text = memo.title
        bodyTextView.text = bodyFromMemo(memo)
        titlePlaceholder.isHidden = !memo.title.isEmpty
        bodyPlaceholder.isHidden = !bodyFromMemo(memo).isEmpty
    }

    func updateCharacter(name: String, image: UIImage?) {
        characterChipButton.setTitle(name, for: .normal)
        characterIconView.image = image ?? UIImage(named: "mokujin")
    }

    func activateTextView() {
        bodyTextView.becomeFirstResponder()
    }

    // MARK: - Private

    @objc private func chipTapped() {
        onCharacterChipTapped?()
    }

    private func bodyFromMemo(_ memo: Memo) -> String {
        memo.body.components(separatedBy: .newlines).dropFirst().joined(separator: "\n")
    }
}

extension MemoComposeView {
    func updatePlaceholders() {
        titlePlaceholder.isHidden = !titleTextView.text.isEmpty
        bodyPlaceholder.isHidden = !bodyTextView.text.isEmpty
    }

    func focusBody() {
        bodyTextView.becomeFirstResponder()
    }

    func setTextViewDelegate(_ delegate: UITextViewDelegate) {
        titleTextView.delegate = delegate
        bodyTextView.delegate = delegate
    }

    // ViewController에서 어떤 textView인지 구분할 수 있도록
    var titleField: UITextView { titleTextView }
    var bodyField: UITextView { bodyTextView }
}

private extension MemoComposeView {
    func setupConstraints() {
        characterRow.translatesAutoresizingMaskIntoConstraints = false
        characterIconView.translatesAutoresizingMaskIntoConstraints = false
        characterChipButton.translatesAutoresizingMaskIntoConstraints = false
        titleTextView.translatesAutoresizingMaskIntoConstraints = false
        titlePlaceholder.translatesAutoresizingMaskIntoConstraints = false
        separator.translatesAutoresizingMaskIntoConstraints = false
        bodyTextView.translatesAutoresizingMaskIntoConstraints = false
        bodyPlaceholder.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Character row
            characterRow.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            characterRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            characterRow.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            characterIconView.leadingAnchor.constraint(equalTo: characterRow.leadingAnchor),
            characterIconView.centerYAnchor.constraint(equalTo: characterRow.centerYAnchor),
            characterIconView.widthAnchor.constraint(equalToConstant: 32),
            characterIconView.heightAnchor.constraint(equalToConstant: 32),

            characterChipButton.leadingAnchor.constraint(equalTo: characterIconView.trailingAnchor, constant: 8),
            characterChipButton.centerYAnchor.constraint(equalTo: characterRow.centerYAnchor),
            characterChipButton.trailingAnchor.constraint(equalTo: characterRow.trailingAnchor),
            characterRow.heightAnchor.constraint(equalToConstant: 32),

            // Title
            titleTextView.topAnchor.constraint(equalTo: characterRow.bottomAnchor, constant: 16),
            titleTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            titlePlaceholder.topAnchor.constraint(equalTo: titleTextView.topAnchor),
            titlePlaceholder.leadingAnchor.constraint(equalTo: titleTextView.leadingAnchor),

            // Separator
            separator.topAnchor.constraint(equalTo: titleTextView.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            // Body
            bodyTextView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            bodyTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            bodyTextView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            bodyTextView.bottomAnchor.constraint(equalTo: bottomAnchor),

            bodyPlaceholder.topAnchor.constraint(equalTo: bodyTextView.topAnchor),
            bodyPlaceholder.leadingAnchor.constraint(equalTo: bodyTextView.leadingAnchor),
        ])
    }
}
