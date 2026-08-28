//
//  WaymarXBannerView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/18/26.
//

import SwiftUI
import GoogleMobileAds

struct WaymarXBannerView: View {

    @StateObject private var consentManager =
        AdMobConsentManager.shared

    var body: some View {

        if consentManager.canRequestAds {

            GeometryReader { geometry in

                let bannerSize = largeAnchoredAdaptiveBanner(
                    width: geometry.size.width
                )

                BannerContainer(adSize: bannerSize)
                    .frame(
                        width: bannerSize.size.width,
                        height: bannerSize.size.height
                    )
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
            }
            .frame(height: 100)

        } else {

            Color.clear
                .frame(height: 0)
        }
    }
}


private struct BannerContainer: UIViewRepresentable {

    let adSize: AdSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {

        let bannerView = BannerView(adSize: adSize)

        // Google's official TEST banner ID
        bannerView.adUnitID =
            "ca-app-pub-3940256099942544/2435281174"

        // Add delegate so we can see success/failure
        bannerView.delegate = context.coordinator

        print("🟡 AdMob: Requesting banner...")

        bannerView.load(Request())

        return bannerView
    }

    func updateUIView(
        _ uiView: BannerView,
        context: Context
    ) {
        uiView.adSize = adSize
    }

    class Coordinator: NSObject, BannerViewDelegate {

        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("🟢 AdMob: Banner loaded successfully")
        }

        func bannerView(
            _ bannerView: BannerView,
            didFailToReceiveAdWithError error: Error
        ) {
            let nsError = error as NSError

            print("🔴 AdMob: Banner FAILED")
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            print("   Description: \(nsError.localizedDescription)")
            print("   UserInfo: \(nsError.userInfo)")
        }
    }
}
