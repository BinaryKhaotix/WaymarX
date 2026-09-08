//
//  ContextualTipBannerView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/3/26.
//

import SwiftUI

struct ContextualTipBannerView: View {

    let tip: ContextualTip
    let onDismiss: () -> Void

    var body: some View {

        VStack(spacing: 14) {

            HStack(alignment: .top, spacing: 12) {

                Image(systemName: tip.systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(tip.title)
                        .font(.headline)

                    Text(tip.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Button {

                onDismiss()

            } label: {

                Text("Got It")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)

            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.15),
            radius: 10,
            y: 4
        )
        .padding(.horizontal, 12)
    }
}
