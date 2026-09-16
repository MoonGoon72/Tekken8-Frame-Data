import Foundation

enum BannerPlacement: String, CaseIterable {
    case characterList = "character_list"
    case moveList = "move_list"
    case memoList = "memo_list"
    case settings
}

struct BannerAdPolicy {
    var enabled = false
    var visible = false
    var keyboardVisible = false
    var editing = false
    var consentAllowsAds = false

    var canLoad: Bool {
        enabled && visible && !keyboardVisible && !editing && consentAllowsAds
    }
}

struct BannerAdConfiguration {
    static let sampleAppID = "ca-app-pub-3940256099942544~1458002511"
    static let sampleBannerID = "ca-app-pub-3940256099942544/2934735716"
    static let sampleNativeID = "ca-app-pub-3940256099942544/3986624511"
    static let remoteKey = "admob_banner_enabled"

    let isDebug: Bool
    let isTesting: Bool
    let appID: String
    let bannerID: String
    let nativeID: String
    let localTestEnabled: Bool

    var adUnitID: String? {
        guard !isTesting else { return nil }
        if isDebug { return Self.sampleBannerID }
        guard Self.isValidID(appID, separator: "~"),
              Self.isValidID(bannerID, separator: "/"),
              !appID.contains("3940256099942544"),
              !bannerID.contains("3940256099942544") else { return nil }
        return bannerID
    }

    var nativeAdUnitID: String? {
        guard !isTesting else { return nil }
        if isDebug { return Self.sampleNativeID }
        guard Self.isValidID(appID, separator: "~"),
              Self.isValidID(nativeID, separator: "/"),
              !appID.contains("3940256099942544"),
              !nativeID.contains("3940256099942544") else { return nil }
        return nativeID
    }

    var hasAnyAdUnitID: Bool { adUnitID != nil || nativeAdUnitID != nil }
    var usesLocalTestAds: Bool { isDebug && localTestEnabled && !isTesting }
    /// Debug uses Google's sample unit; Release requires the app's real IDs.
    var usesNativeMoveAds: Bool { !isTesting && nativeAdUnitID != nil }

    private static func isValidID(_ value: String, separator: String) -> Bool {
        value.range(of: "^ca-app-pub-[0-9]{16}" + separator + "[0-9]{10}$", options: .regularExpression) != nil
    }

    static var current: Self {
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        return Self(
            isDebug: isDebug,
            isTesting: ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil,
            appID: Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? "",
            bannerID: Bundle.main.object(forInfoDictionaryKey: "AdMobBannerAdUnitID") as? String ?? "",
            nativeID: Bundle.main.object(forInfoDictionaryKey: "AdMobNativeAdUnitID") as? String ?? "",
            // Debug builds must always render Google's test creative so the banner
            // layout can be inspected without enabling production monetization.
            localTestEnabled: isDebug
        )
    }
}
