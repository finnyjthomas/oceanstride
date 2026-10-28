import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

/// Real Google test ads in Debug; production requests require explicit configuration.
@MainActor
final class RewardedAds: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var isBusy = false
    @Published private(set) var isPresenting = false
    @Published private(set) var needsPrivacyOptions = false
    @Published private(set) var status = ""
    private var consentTask: Task<Void, Error>?
    private var work: Task<Void, Never>?
    private var requestID: UUID?
    private var ad: RewardedAd?
    private var earnedReward = false
    private var completion: ((Bool) -> Void)?
    private var startedSDK = false

    var enabled: Bool {
        #if DEBUG
        return true
        #else
        let info = Bundle.main.infoDictionary ?? [:]
        let appID = info["GADApplicationIdentifier"] as? String ?? ""
        let unitID = info["OceanRewardedAdUnitID"] as? String ?? ""
        return info["OceanLiveAdsEnabled"] as? String == "YES" &&
            appID.hasPrefix("ca-app-pub-") && appID.contains("~") &&
            unitID.hasPrefix("ca-app-pub-") && unitID.contains("/") &&
            !appID.contains("3940256099942544") && !unitID.contains("3940256099942544")
        #endif
    }

    private var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/1712485313"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "OceanRewardedAdUnitID") as? String ?? ""
        #endif
    }

    /// Refresh consent every launch, but do not interrupt a run with a form or load an ad.
    func updateConsentAtLaunch() async {
        guard enabled else { return }
        do { try await refreshConsent() } catch { /* Retry on explicit ad request. */ }
    }

    private func refreshConsent() async throws {
        if let consentTask { return try await consentTask.value }
        let task = Task { @MainActor in
            let parameters = RequestParameters()
            parameters.isTaggedForUnderAgeOfConsent = false
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
        }
        consentTask = task
        do {
            try await task.value
            needsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        } catch {
            consentTask = nil
            throw error
        }
    }

    func watchForLevelSkip(completion: @escaping (Bool) -> Void) {
        guard enabled, !isBusy else { completion(false); return }
        let id = UUID()
        requestID = id
        self.completion = completion
        earnedReward = false
        isBusy = true
        status = "Loading an optional ad… You can still retry or return to the menu."
        work = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await refreshConsent()
                try Task.checkCancellation()
                guard requestID == id, let presenter = Self.presenter else { throw AdError.unavailable }
                try await ConsentForm.loadAndPresentIfRequired(from: presenter)
                needsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
                try Task.checkCancellation()
                guard requestID == id, ConsentInformation.shared.canRequestAds else { throw AdError.unavailable }
                if !startedSDK {
                    MobileAds.shared.requestConfiguration.maxAdContentRating = .general
                    MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
                    MobileAds.shared.requestConfiguration.setPublisherFirstPartyIDEnabled(false)
                    await MobileAds.shared.start()
                    startedSDK = true
                }
                try Task.checkCancellation()
                let request = Request()
                let extras = Extras()
                extras.additionalParameters = ["npa": "1"]
                request.register(extras)
                let loadedAd = try await RewardedAd.load(with: adUnitID, request: request)
                try Task.checkCancellation()
                guard requestID == id, UIApplication.shared.applicationState == .active,
                      let presenter = Self.presenter else { throw AdError.unavailable }
                ad = loadedAd
                loadedAd.fullScreenContentDelegate = self
                try loadedAd.canPresent(from: presenter)
                isPresenting = true
                status = ""
                loadedAd.present(from: presenter) { [weak self] in
                    guard let self, self.requestID == id else { return }
                    // Only the SDK's earned-reward callback authorizes a level skip.
                    self.earnedReward = true
                }
            } catch {
                guard requestID == id else { return }
                status = "No ad available right now. Try again, retry the level, or return to the menu."
                finish(earned: false)
            }
        }
    }

    func cancelPending() {
        guard !isPresenting else { return }
        work?.cancel()
        status = ""
        finish(earned: false)
    }

    private func finish(earned: Bool) {
        let callback = completion
        completion = nil
        requestID = nil
        ad = nil
        isBusy = false
        isPresenting = false
        earnedReward = false
        callback?(earned)
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        guard (ad as AnyObject) === self.ad else { return }
        let earned = earnedReward
        if !earned { status = "Ad closed without a reward. Retry the level or try another ad." }
        finish(earned: earned)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        guard (ad as AnyObject) === self.ad else { return }
        status = "The ad could not be shown. You can retry normally."
        finish(earned: false)
    }

    func showPrivacyOptions() {
        guard enabled, needsPrivacyOptions, !isBusy, let presenter = Self.presenter else { return }
        Task { @MainActor in
            do { try await ConsentForm.presentPrivacyOptionsForm(from: presenter) }
            catch { status = "Privacy options are temporarily unavailable. Please try again." }
            needsPrivacyOptions = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        }
    }

    private static var presenter: UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        return controller
    }
    private enum AdError: Error { case unavailable }
}

enum AppPrivacy {
    /// Set the same public HTTPS URL in App Store Connect and both build configurations.
    static var policyURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "OceanPrivacyPolicyURL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

struct AdPrivacyView: View {
    @ObservedObject var ads: RewardedAds
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                if let policyURL = AppPrivacy.policyURL {
                    Section {
                        Link(destination: policyURL) {
                            Label("Ocean Stride privacy policy", systemImage: "arrow.up.right.square")
                        }
                    }
                }
                #if DEBUG
                if AppPrivacy.policyURL == nil {
                    Section { Text("Privacy policy URL is not configured. Set OCEAN_PRIVACY_POLICY_URL before App Store submission.").font(.footnote) }
                }
                #endif
                Section("Your game progress") {
                    Text("Your level, jewels, boost time, daily ad skips, and best score are saved on this device. Ocean Stride has no player account.")
                }
                Section("Optional rewarded ads") {
                    Text("Watching an ad is optional. Completing an ad can skip to the next level, up to twice per local calendar day on this device. Retrying and returning to the menu are always free.")
                    Text("Google's advertising and consent services use network connections and may process device information, IP-derived approximate location, ad interactions, and diagnostics. We request non-personalized ads and do not request tracking permission.")
                    Link("Google advertising privacy", destination: URL(string: "https://policies.google.com/technologies/ads")!)
                    if ads.needsPrivacyOptions {
                        Button("Change ad privacy choices") { ads.showPrivacyOptions() }
                    }
                    if !ads.status.isEmpty { Text(ads.status).font(.footnote) }
                }
                #if DEBUG
                Section { Text("This build uses Google's test ads. Test ads do not generate revenue.") }
                #endif
            }
            .navigationTitle("Privacy & ads")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
