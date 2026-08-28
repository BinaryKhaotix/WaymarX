//
//  SplashScreenView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 3/26/25.
//
import SwiftUI

struct SplashScreenView: View {

    let onFinished: () -> Void

    @State private var showText = false
    @State private var hasScheduledDismiss = false
    @State private var reveal = false

    // timing
    private let introDuration: Double = 0.35
    private let visibleHold: Double = 1.50

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            // Center "pinpoint" reveal of the background image
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let maxRadius = sqrt(w*w + h*h) // diagonal length

                Image("Binary Khaotix LOGO")
                    .resizable()
                    .scaledToFill()
                    .frame(width: w, height: h, alignment: .center)
                    .clipped()
                    .mask(
                        Circle()
                            .frame(width: maxRadius * 2, height: maxRadius * 2)
                            .scaleEffect(reveal ? 1.0 : 0.001, anchor: .center) // pinpoint -> full
                            .frame(width: w, height: h, alignment: .center)      // keep mask centered
                    )
                    .animation(.easeOut(duration: 0.35), value: reveal)
            }
            .ignoresSafeArea()

            ScanlinesView()
                .opacity(0.10)
                .ignoresSafeArea()

            // Text + unified translucent background block
            VStack {
                Spacer()

                VStack(spacing: 10) {
                    Text("Binary Khaotix")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(Color("Light Orange"))
                        .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 3)

                    Text("DEVELOPER COLLECTIVE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.90))
                        .tracking(2.5)

                    Text("Engineering Order From Chaos")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.70))
                        .italic()

                    Text("v\(Bundle.main.appVersion)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .padding(.top, 6)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.gray.opacity(0.7)) // translucent grey scrim
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.20), lineWidth: 1)
                )

                Spacer()
                    .frame(height: 44)
            }
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 14)
            .animation(.easeOut(duration: introDuration), value: showText)
        }
        .onAppear {
            showText = true

            guard !hasScheduledDismiss else { return }
            hasScheduledDismiss = true

            Task { @MainActor in
                // Let layout settle so the reveal truly originates from screen center
                await Task.yield()
                reveal = true

                let total = introDuration + visibleHold
                try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
                onFinished()
            }
        }
    }
}

// MARK: - Scanlines
private struct ScanlinesView: View {
    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let lineHeight: CGFloat = 3

            VStack(spacing: 0) {
                ForEach(0..<Int(height / lineHeight), id: \.self) { idx in
                    Rectangle()
                        .fill(Color.white.opacity(idx.isMultiple(of: 2) ? 0.06 : 0.0))
                        .frame(height: lineHeight)
                }
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - App Version Helper
private extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}



//import SwiftUI
//
//struct SplashScreenView: View {
//
//    let onFinished: () -> Void
//
//    @State private var showText = false
//    @State private var pulse = false
//    @State private var grow = false
//    @State private var hasScheduledDismiss = false
//    @State private var reveal = false
//
//
//
//    // timing
//    private let introDuration: Double = 0.35
//    private let visibleHold: Double = 1.50
//
//    var body: some View {
//        ZStack {
//            Color.black
//                .ignoresSafeArea()
//
//            GeometryReader { geo in
//                let w = geo.size.width
//                let h = geo.size.height
//                let maxRadius = sqrt(w*w + h*h) // diagonal length
//
//                Image("Binary Khaotix LOGO")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: w, height: h, alignment: .center)
//                    .clipped()
//                    .mask(
//                        Circle()
//                            .frame(width: maxRadius * 2, height: maxRadius * 2)
//                            .scaleEffect(reveal ? 1.0 : 0.001, anchor: .center) // pinpoint -> full
//                            .frame(width: w, height: h, alignment: .center)      // keep mask centered
//                    )
//                    .animation(.easeOut(duration: 0.2), value: reveal)
//            }
//            .ignoresSafeArea()
//
//
//            ScanlinesView()
//                .opacity(0.10)
//                .ignoresSafeArea()
//
//            VStack(spacing: 10) {
//                Spacer()
//
//                Text("Binary Khaotix")
//                    .font(.system(size: 36, weight: .bold, design: .rounded))
//                    .foregroundStyle(Color("Light Orange"))
//                    .shadow(color: .black.opacity(0.7), radius: 8, x: 0, y: 3)
//
//                Text("DEVELOPER COLLECTIVE")
//                    .font(.system(size: 13, weight: .semibold))
//                    .foregroundColor(.white.opacity(0.90))
//                    .tracking(2.5)
//
//                Text("Engineering Order From Chaos")
//                    .font(.system(size: 12, weight: .regular))
//                    .foregroundColor(.white.opacity(0.70))
//                    .italic()
//
//                Text("v\(Bundle.main.appVersion)")
//                    .font(.system(size: 11, weight: .medium))
//                    .foregroundColor(.white.opacity(0.55))
//                    .padding(.top, 6)
//
//                Spacer()
//                    .frame(height: 44)
//            }
//            .opacity(showText ? 1 : 0)
//            .offset(y: showText ? 0 : 14)
//            .animation(.easeOut(duration: introDuration), value: showText)
//        }
//        .onAppear {
//            reveal = true
//            showText = true
//
//            guard !hasScheduledDismiss else { return }
//            hasScheduledDismiss = true
//
//            Task { @MainActor in
//                let total = introDuration + visibleHold
//                try? await Task.sleep(nanoseconds: UInt64(total * 1_000_000_000))
//                onFinished()
//            }
//        }
//    }
//}
//
//// MARK: - Scanlines
//private struct ScanlinesView: View {
//    var body: some View {
//        GeometryReader { geo in
//            let height = geo.size.height
//            let lineHeight: CGFloat = 3
//
//            VStack(spacing: 0) {
//                ForEach(0..<Int(height / lineHeight), id: \.self) { idx in
//                    Rectangle()
//                        .fill(Color.white.opacity(idx.isMultiple(of: 2) ? 0.06 : 0.0))
//                        .frame(height: lineHeight)
//                }
//            }
//        }
//        .blendMode(.overlay)
//        .allowsHitTesting(false)
//    }
//}
//
//// MARK: - App Version Helper
//private extension Bundle {
//    var appVersion: String {
//        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
//        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
//        return "\(version) (\(build))"
//    }
//}





//import SwiftUI
//
//struct SplashScreenView: View {
//    @State private var isActive = false  // Controls navigation to ContentView
//    
//    var body: some View {
//        GeometryReader { geometry in
//            ZStack {
//                // Black background filling the view
//                Color.black
//                    .ignoresSafeArea()
//                
//                // Background logo (ensure "Binary Khaotix LOGO" is in your asset catalog)
//                Image("Binary Khaotix LOGO")
//                    .resizable()
//                    .scaledToFill()
//                    .frame(width: geometry.size.width, height: geometry.size.height)
//                    .ignoresSafeArea()
//                    .zIndex(-1)
//                
//                let midX = geometry.size.width / 2
//                let midY = geometry.size.height / 2
//                
//                // Title: "Crumbz!" (Converted from SpriteKit coordinates)
//                LabelWithTightBackground(
//                    text: "WaymarX",
//                    font: .custom("Marker Felt", size: 75),
//                    fontColor: .white
//                )
//                .position(x: midX, y: geometry.size.height - (midY + 300))
//                
//                // Subtitle: "Bits Arranged by:"
//                LabelWithTightBackground(
//                    text: "Bits Arranged by:",
//                    font: .custom("Herculanum", size: 20),
//                    fontColor: .white
//                )
//                .position(x: 113, y: geometry.size.height - (midY - 200))
//                
//                // Developer: "Binary Khaotix"
//                LabelWithTightBackground(
//                    text: "Binary Khaotix",
//                    font: .custom("Herculanum", size: 48),
//                    fontColor: .white
//                )
//                .position(x: midX, y: geometry.size.height - (midY - 232))
//                
//                // Copyright
//                LabelWithTightBackground(
//                    text: "Copywrite (c) 2025 - Freedom Automation, Inc.",
//                    font: .custom("Arial", size: 16),
//                    fontColor: .white
//                )
//                .position(x: midX, y: geometry.size.height - (midY - 440))
//            }
//            .onAppear {
//                // Transition to ContentView after 1 second
//                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//                    print("SplashDidFinish")
//                    withAnimation {
//                        isActive = true
//                    }
//                }
//            }
//        }
//        .fullScreenCover(isPresented: $isActive) {
//            ContentView()  // Navigate to your ContentView
//        }
//    }
//}
//
//struct LabelWithTightBackground: View {
//    let text: String
//    let font: Font
//    let fontColor: Color
//    
//    var body: some View {
//        Text(text)
//            .font(font)
//            .foregroundColor(fontColor)
//            .padding(16)  // Mimics the text padding from SpriteKit
//            .background(Color.black.opacity(0.5))  // Semi-transparent black background
//            .cornerRadius(8)
//    }
//}
//
//
//struct SplashScreenView_Previews: PreviewProvider {
//    static var previews: some View {
//        SplashScreenView()
//    }
//}
//
//
//#Preview {
//    SplashScreenView()
//}
