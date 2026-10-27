import UIKit

class SettingViewController: BaseViewController {
    private let tableView: SettingTableView
    private var settingsSections: [[SettingItem]] {
        var items: [SettingItem] = [.removeAds, .reportIssue]
        if ads?.privacyOptionsRequired == true { items.append(.adPrivacy) }
        #if DEBUG
        if ads?.configuration.usesMediationTestAds == true { items.append(.adInspector) }
        #endif
        return [[.appearance], items]
    }
    private let ads: BannerAdService?
    private let purchaseViewModel: SettingsPurchaseViewModel
    private let appearance: AppAppearance
    private let makePurchaseNotice: ((SettingsPurchaseViewModel) -> PurchaseNoticeViewController)?

    private let analytics: AnalyticsClient

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.log(.screenViewed(.settings))
        presentPendingPurchaseMessage()
        Task { await purchaseViewModel.prepare() }
    }

    init(analytics: AnalyticsClient, ads: BannerAdService? = nil, purchaseViewModel: SettingsPurchaseViewModel,
         makePurchaseNotice: ((SettingsPurchaseViewModel) -> PurchaseNoticeViewController)? = nil,
         appearance: AppAppearance? = nil) {
        self.analytics = analytics
        self.ads = ads
        self.purchaseViewModel = purchaseViewModel
        self.makePurchaseNotice = makePurchaseNotice
        self.appearance = appearance ?? AppAppearance(repository: DefaultAppThemeRepository(manager: UserDefaultsManager()))
        tableView = SettingTableView()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        view = tableView
        title = Constants.Literals.title
        view.backgroundColor = .tkBackground
    }

    override func setupDelegation() {
        setupTableViewDelegation()
    }

    override func setupNavigationBar() {
        super.setupNavigationBar()
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.tintColor = .tkRed
        navigationItem.largeTitleDisplayMode = .always
    }

    override func bindViewModel() {
        appearance.$theme.removeDuplicates().sink { [weak self] _ in
            DispatchQueue.main.async { self?.tableView.tableView.reloadData() }
        }.store(in: &subscriptionSet)
        purchaseViewModel.$state.combineLatest(purchaseViewModel.$isPreparing).sink { [weak self] _ in
            DispatchQueue.main.async { self?.tableView.tableView.reloadData() }
        }.store(in: &subscriptionSet)
        purchaseViewModel.$message.compactMap { $0 }.sink { [weak self] _ in
            // @Published는 값 대입 전에 알린다. 다음 메인 큐 작업에서 현재 메시지를 읽는다.
            DispatchQueue.main.async { self?.presentPendingPurchaseMessage() }
        }.store(in: &subscriptionSet)
        ads?.$privacyOptionsRequired.removeDuplicates().sink { [weak self] _ in
            // 값 대입 전에 변경 알림이 오므로 화면 갱신은 다음 메인 큐 작업에서 실행한다.
            DispatchQueue.main.async { self?.tableView.tableView.reloadData() }
        }.store(in: &subscriptionSet)
    }

    private func presentPendingPurchaseMessage() {
        guard navigationController?.topViewController === self,
              viewIfLoaded?.window != nil, presentedViewController == nil,
              !isBeingDismissed, let message = purchaseViewModel.message else { return }
        let alert = UIAlertController(title: "Ad removal".localized(), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
        present(alert, animated: true)
        purchaseViewModel.clearMessage()
    }

    private func setupTableViewDelegation() {
        tableView.setTableViewDelegate(self)
        tableView.setTableViewDataSource(self)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Constants.Literals.cellIdentifier)
    }
    
    static func openSupportPage(from presenter: UIViewController) {
        let url = URL(string: "https://moongoon72.github.io/Tekken8-Frame-Data/support/")!
        UIApplication.shared.open(url, options: [:]) { opened in
            guard !opened else { return }
            DispatchQueue.main.async {
                guard presenter.presentedViewController == nil else { return }
                let alert = UIAlertController(title: "Contact developer".localized(),
                                              message: "Unable to open the page. Please try again.".localized(),
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
                presenter.present(alert, animated: true)
            }
        }
    }
}

extension SettingViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { settingsSections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsSections[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.Literals.cellIdentifier, for: indexPath)
        let item = settingsSections[indexPath.section][indexPath.row]

        cell.backgroundColor = .tkSurface

        // 텍스트 스타일
        var configuration = item == .appearance && !traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? UIListContentConfiguration.valueCell() : cell.defaultContentConfiguration()
        configuration.text = item.title
        configuration.textProperties.color = .tkPrimaryText
        configuration.textProperties.font = .preferredFont(forTextStyle: .body)
        configuration.textProperties.numberOfLines = 0
        configuration.secondaryTextProperties.numberOfLines = 0
        configuration.secondaryText = item == .appearance ? appearance.theme.title : nil
        configuration.image = UIImage(systemName: item.symbolName)
        configuration.imageProperties.tintColor = item == .removeAds ? .tkRed : .tkSecondaryText
        configuration.imageProperties.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        configuration.imageToTextPadding = 12
        if item == .removeAds {
            configuration.secondaryText = purchaseViewModel.state.entitlement == .adFree
                ? "Ads removed".localized()
                : "One-time purchase. No automatic renewal.".localized()
        }
        configuration.secondaryTextProperties.color = .tkSecondaryText
        cell.contentConfiguration = configuration
        cell.isUserInteractionEnabled = !purchaseViewModel.state.isBusy || item != .removeAds

        // 큰 글씨에서도 줄바꿈할 수 있도록 버전 정보는 제목 아래에 표시한다.
        cell.accessoryView = nil

        // 이동 화살표 색상
        cell.accessoryType = item.showsDisclosureIndicator ? .disclosureIndicator : .none
        cell.tintColor = .tkSecondaryText

        // 선택 시 하이라이트
        let selectdBackground = UIView()
        selectdBackground.backgroundColor = .tkMutedSurface
        cell.selectedBackgroundView = selectdBackground

        // 구분선 색상
        if indexPath.row < settingsSections[indexPath.section].count - 1 {
            cell.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        } else {
            // 마지막 셀에는 구분선을 표시하지 않는다.
            cell.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: .greatestFiniteMagnitude)
        }

        return cell
    }
}

extension SettingViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        (section == 0 ? "Appearance" : "Usage and support").localized()
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == settingsSections.count - 1 else { return nil }
        return SettingsInfoFooterView(appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            dataVersion: UserDefaults.standard.string(forKey: Constants.Literals.tekkenVersion))
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = settingsSections[indexPath.section][indexPath.row]
        
        switch item {
        case .appearance:
            let picker = ThemeSelectionViewController(appearance: appearance)
            let navigation = UINavigationController(rootViewController: picker)
            navigation.modalPresentationStyle = .pageSheet
            navigation.sheetPresentationController?.detents = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? [.large()] : [.medium(), .large()]
            navigation.sheetPresentationController?.prefersGrabberVisible = true
            present(navigation, animated: true)
        case .removeAds:
            guard !purchaseViewModel.state.isBusy else { return }
            let notice = makePurchaseNotice?(purchaseViewModel) ?? PurchaseNoticeViewController(viewModel: purchaseViewModel) { presenter in
                Self.openSupportPage(from: presenter)
            }
            navigationController?.pushViewController(notice, animated: true)
        #if DEBUG
        case .adInspector:
            Task {
                do {
                    try await ads?.presentAdInspector(from: self)
                } catch {
                    let alert = UIAlertController(title: "Ad Inspector (test)".localized(),
                                                  message: "Complete ad consent and register this test device before opening Ad Inspector.".localized(),
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
                    present(alert, animated: true)
                }
            }
        #endif
        case .reportIssue:
            Self.openSupportPage(from: self)
        case .adPrivacy:
            Task {
                do {
                    try await ads?.presentPrivacyOptions(from: self)
                } catch {
                    let alert = UIAlertController(title: "Ad privacy options".localized(),
                                                  message: "Unable to load privacy options. Please try again.".localized(),
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Accept".localized(), style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }
}

private extension SettingViewController {
    enum SettingItem {
        case appearance
        case reportIssue
        case adPrivacy
        case removeAds
        #if DEBUG
        case adInspector
        #endif
        
        var title: String {
            switch self {
            case .removeAds: "Ad removal".localized()
            #if DEBUG
            case .adInspector:
                "Ad Inspector (test)".localized()
            #endif
            case .appearance:
                "Screen theme".localized()
            case .reportIssue:
                "Contact and report a problem".localized()
            case .adPrivacy:
                "Ad privacy options".localized()
            }
        }
        
        var symbolName: String {
            switch self {
            case .appearance: "moon.stars"
            case .removeAds: "sparkles"
            case .reportIssue: "bubble.left"
            case .adPrivacy: "hand.raised"
            #if DEBUG
            case .adInspector: "wrench.and.screwdriver"
            #endif
            }
        }
        
        var showsDisclosureIndicator: Bool {
            switch self {
            #if DEBUG
            case .adInspector:
                true
            #endif
            case .appearance, .removeAds, .reportIssue, .adPrivacy:
                true
            }
        }
    }
    
    enum Constants {
        enum Literals {
            static let cellIdentifier = "SettingCell"
            static let title = "Settings".localized()
            static let tekkenVersion = "TekkenVersion"
        }
    }
}
