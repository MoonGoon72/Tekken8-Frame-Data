import UIKit

@MainActor
final class ThemeSelectionViewController: UITableViewController {
    private let appearance: AppAppearance

    init(appearance: AppAppearance) {
        self.appearance = appearance
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Screen theme".localized()
        AppNavigationStyle.apply(to: navigationController?.navigationBar)
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        view.backgroundColor = .tkBackground
        tableView.backgroundColor = .tkBackground
        tableView.separatorColor = .tkSeparator
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "theme")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { AppTheme.allCases.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let theme = AppTheme.allCases[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "theme", for: indexPath)
        cell.backgroundColor = .tkSurface
        var content = cell.defaultContentConfiguration()
        content.text = theme.title
        content.secondaryText = theme == .dark ? "Default appearance".localized() : nil
        content.textProperties.color = .tkPrimaryText
        content.secondaryTextProperties.color = .tkSecondaryText
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.image = UIImage(systemName: theme.symbolName)
        content.imageProperties.tintColor = .tkSecondaryText
        cell.contentConfiguration = content
        cell.tintColor = .tkRed
        cell.accessoryType = appearance.theme == theme ? .checkmark : .none
        cell.accessibilityTraits = appearance.theme == theme ? [.button, .selected] : [.button]
        cell.accessibilityIdentifier = "theme_" + theme.rawValue
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        do {
            try appearance.select(AppTheme.allCases[indexPath.row])
            tableView.reloadData()
            dismiss(animated: true)
        } catch {
            let alert = UIAlertController(title: "Screen theme".localized(),
                message: "Unable to save the theme. Please try again.".localized(), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
            present(alert, animated: true)
        }
    }
}
