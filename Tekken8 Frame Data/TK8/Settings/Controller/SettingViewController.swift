import MessageUI
import UIKit

class SettingViewController: BaseViewController, MFMailComposeViewControllerDelegate {

    private let tableView: SettingTableView
    private let settingsItems: [SettingItem] = [
        .appVersion,
        .tekkenVersion,
        .reportIssue,
        .donate
    ]

    init() {
        tableView = SettingTableView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        view = tableView
        // TODO: localizing
        title = Constants.Literals.title
    }
    
    override func setupDelegation() {
        setupTableViewDelegation()
    }

    private func setupTableViewDelegation() {
        tableView.setTableViewDelegate(self)
        tableView.setTableViewDataSource(self)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.Literals.cellIdentifier)
    }
    
    private func sendReportMail() {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([Constants.Literals.Report.email])
            mail.setSubject(Constants.Literals.Report.title)
            mail.setMessageBody(Constants.Literals.Report.body, isHTML: true)
            present(mail, animated: true)
        } else {
            let alert = UIAlertController(title: Constants.Literals.Report.sendFailTitle, message: Constants.Literals.Report.sendFailMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Constants.Literals.Report.alertAccept, style: .default))
            present(alert, animated: true)
        }
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

extension SettingViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Literals.cellIdentifier, for: indexPath)
        let item = settingsItems[indexPath.row]
        cell.textLabel?.text = item.title

        if let accessory = item.accessoryText {
            let versionLabel = UILabel()
            versionLabel.text = accessory
            versionLabel.textColor = .secondaryLabel
            versionLabel.sizeToFit()
            cell.accessoryView = versionLabel
        } else {
            cell.accessoryView = nil
        }
        
        cell.accessoryType = item.showsDisclosureIndicator ? .disclosureIndicator : .none
        return cell
    }
}

extension SettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = settingsItems[indexPath.row]
        
        switch item {
        case .reportIssue:
            sendReportMail()
        case .donate:
            let alert = UIAlertController(title: "준비 중", message: "곧 찾아뵙겠습니다!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
        default:
            break
        }
    }
}

private extension SettingViewController {
    enum SettingItem {
        case appVersion
        case tekkenVersion
        case reportIssue
        case donate
        
        var title: String {
            switch self {
            case .appVersion:
                "앱 버전".localized()
            case .tekkenVersion:
                "철권 버전".localized()
            case .reportIssue:
                "문제 신고".localized()
            case .donate:
                "인앱 후원".localized()
            }
        }
        
        var accessoryText: String? {
            switch self {
            case .appVersion:
                Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            case .tekkenVersion:
                UserDefaults.standard.string(forKey: Constants.Literals.tekkenVersion)
            default:
                nil
            }
        }
        
        var showsDisclosureIndicator: Bool {
            switch self {
            case .reportIssue, .donate:
                true
            default:
                false
            }
        }
    }
    
    enum Constants {
        enum Literals {
            static let cellIdentifier = "SettingCell"
            static let title = "설정".localized()
            static let tekkenVersion = "TekkenVersion"
            enum Report {
                static let email = "moongoon.cnu@gmail.com"
                static let title = "Tekken8 Frame Data Bug Report"
                static let body = "<p>버그 리포트, 건의사항, 프레임 데이터 오입력 등등을 제보해주세요.</p>".localized()
                static let sendFailTitle = "메일 전송 실패".localized()
                static let sendFailMessage = "메일 설정을 확인해주세요.".localized()
                static let alertAccept = "확인".localized()
            }
        }
    }
}
