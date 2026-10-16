import AppTrackingTransparency
import GoogleMobileAds
import Observation
import UIKit
import UserMessagingPlatform

/// Every AdMob call lives here. Game code only asks "is a rewarded ad ready?",
/// "show one", and "a run just finished, maybe show an interstitial".
///
/// Rules: never during a run; rewarded ads are always the player's choice;
/// interstitials are capped (see `Rules`).
@Observable
final class Ads: NSObject {
    static let shared = Ads()

    enum Units {
        #if DEBUG
        // Google's public test units. Never click real ads during development.
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        #else
        // TODO: replace with the real ad unit IDs from the AdMob console before release.
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        static let rewarded = "ca-app-pub-3940256099942544/1712485313"
        #endif
    }

    enum Rules {
        static let interstitialEveryRuns = 3
        static let interstitialCooldown: TimeInterval = 120
        static let noInterstitialBeforeRuns = 3
        static let shopRewardsPerDay = 5
        static let shopReward = 15
        static let continueMinScore = 10
    }

    private(set) var rewardedReady = false
    private(set) var privacyOptionsRequired = false
    /// Set by a future "Remove Ads" purchase; turns off interstitials only.
    var adsRemoved = false

    @ObservationIgnored private var started = false
    @ObservationIgnored private var interstitial: InterstitialAd?
    @ObservationIgnored private var rewarded: RewardedAd?
    @ObservationIgnored private var lastInterstitial: Date = .distantPast
    @ObservationIgnored private var runsSinceInterstitial = 0
    @ObservationIgnored private var rewardedWatchedThisScreen = false
    @ObservationIgnored private var onDismiss: (() -> Void)?
    @ObservationIgnored private var loadingRewarded = false
    @ObservationIgnored private var loadingInterstitial = false

    // MARK: - Startup

    /// Consent (UMP) first, then the SDK. Safe to call more than once.
    @MainActor
    func start() {
        #if DEBUG
        // `-noAds YES`: no consent form, no SDK (marketing captures, UI work)
        if UserDefaults.standard.bool(forKey: "noAds") { return }
        #endif
        let params = RequestParameters()
        params.isTaggedForUnderAgeOfConsent = false
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] _ in
            guard let self else { return }
            ConsentForm.loadAndPresentIfRequired(from: nil) { [weak self] _ in
                guard let self else { return }
                self.privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                self.startSDKIfAllowed()
            }
        }
        // Consent from a previous session may already allow ads.
        startSDKIfAllowed()
    }

    @MainActor
    private func startSDKIfAllowed() {
        guard ConsentInformation.shared.canRequestAds, !started else { return }
        started = true
        let config = MobileAds.shared.requestConfiguration
        config.maxAdContentRating = .general
        MobileAds.shared.start { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadRewarded()
                self?.loadInterstitial()
            }
        }
    }

    /// App Tracking Transparency, asked once after the first finished run (never at launch).
    @MainActor
    func requestTrackingIfNeeded() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "noAds") { return }
        #endif
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async { self.loadRewarded(); self.loadInterstitial() }
        }
    }

    @MainActor
    func showPrivacyOptions() {
        ConsentForm.presentPrivacyOptionsForm(from: Self.topViewController()) { _ in }
    }

    // MARK: - Loading

    @MainActor
    private func loadRewarded() {
        guard started, rewarded == nil, !loadingRewarded else { return }
        loadingRewarded = true
        RewardedAd.load(with: Units.rewarded, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadingRewarded = false
                self.rewarded = ad
                ad?.fullScreenContentDelegate = self
                self.rewardedReady = ad != nil
                if ad == nil { self.retry { self.loadRewarded() } }
            }
        }
    }

    @MainActor
    private func loadInterstitial() {
        guard started, interstitial == nil, !loadingInterstitial else { return }
        loadingInterstitial = true
        InterstitialAd.load(with: Units.interstitial, request: Request()) { [weak self] ad, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.loadingInterstitial = false
                self.interstitial = ad
                ad?.fullScreenContentDelegate = self
                if ad == nil { self.retry { self.loadInterstitial() } }
            }
        }
    }

    private func retry(_ f: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { MainActor.assumeIsolated { f() } }
    }

    // MARK: - Showing

    /// Shows a rewarded ad. `done(true)` only if the reward was earned.
    @MainActor
    func showRewarded(_ done: @escaping (Bool) -> Void) {
        guard let ad = rewarded, let vc = Self.topViewController() else { done(false); return }
        var earned = false
        rewarded = nil
        rewardedReady = false
        rewardedWatchedThisScreen = true
        onDismiss = { done(earned) }
        Audio.shared.suspend(true)
        ad.present(from: vc) { earned = true }
    }

    /// Call when the player leaves the game-over screen. Runs `then` right away if no ad is due,
    /// otherwise after the interstitial is dismissed.
    @MainActor
    func leavingGameOver(store: GameStore, then: @escaping () -> Void) {
        defer { rewardedWatchedThisScreen = false }
        runsSinceInterstitial += 1
        let due = !adsRemoved
            && store.runs > Rules.noInterstitialBeforeRuns
            && runsSinceInterstitial >= Rules.interstitialEveryRuns
            && Date().timeIntervalSince(lastInterstitial) >= Rules.interstitialCooldown
            && !rewardedWatchedThisScreen
        guard due, let ad = interstitial, let vc = Self.topViewController() else { then(); return }
        interstitial = nil
        runsSinceInterstitial = 0
        lastInterstitial = Date()
        onDismiss = then
        Audio.shared.suspend(true)
        ad.present(from: vc)
    }

    @MainActor
    private func finish() {
        Audio.shared.suspend(false)
        let f = onDismiss
        onDismiss = nil
        f?()
        loadRewarded()
        loadInterstitial()
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var vc = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}

extension Ads: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        DispatchQueue.main.async { self.finish() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        DispatchQueue.main.async { self.finish() }
    }
}
