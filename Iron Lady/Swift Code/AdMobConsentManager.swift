//
//  AdMobConsentManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/18/26.
//

import Foundation
import UserMessagingPlatform
import GoogleMobileAds

@MainActor
final class AdMobConsentManager: ObservableObject {

    static let shared = AdMobConsentManager()

    @Published var canRequestAds = false
    @Published var privacyOptionsRequired = false

    private var hasStartedMobileAds = false

    private init() {}

    func gatherConsent() async {

        let parameters = RequestParameters()

        do {

            try await ConsentInformation.shared.requestConsentInfoUpdate(
                with: parameters
            )

            try await ConsentForm.loadAndPresentIfRequired(from: nil)

            canRequestAds = ConsentInformation.shared.canRequestAds

            privacyOptionsRequired =
                ConsentInformation.shared.privacyOptionsRequirementStatus == .required

            if canRequestAds {
                startMobileAds()
            }

        } catch {

            print("AdMob consent error: \(error.localizedDescription)")

            canRequestAds = ConsentInformation.shared.canRequestAds

            if canRequestAds {
                startMobileAds()
            }
        }
    }

    private func startMobileAds() {

        guard !hasStartedMobileAds else {
            return
        }

        hasStartedMobileAds = true

        MobileAds.shared.start()
    }

    func showPrivacyOptions() async {

        do {

            try await ConsentForm.presentPrivacyOptionsForm(from: nil)

            canRequestAds = ConsentInformation.shared.canRequestAds

        } catch {

            print("Privacy options error: \(error.localizedDescription)")
        }
    }
}
