import Foundation

protocol AdRemovalNoticeRepository {
    var isConsumed: Bool { get }
    func consume()
}

/// 안내 처리 여부만 저장한다. 구매 권한은 StoreKit이 소유한다.
final class DefaultAdRemovalNoticeRepository: AdRemovalNoticeRepository {
    private let manager: any UserDefaultsManageable
    private static let key = "ad_removal_notice_consumed"

    init(manager: any UserDefaultsManageable) {
        self.manager = manager
    }

    var isConsumed: Bool {
        (try? manager.fetch(Bool.self, forKey: Self.key)) ?? false
    }

    func consume() {
        try? manager.update(true, forKey: Self.key)
    }
}
