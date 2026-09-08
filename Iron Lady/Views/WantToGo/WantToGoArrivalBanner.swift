//
//  WantToGoArrivalBanner.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/3/26.
//

import SwiftUI

struct WantToGoArrivalBanner: View {

    let destinationName: String
    let onHere: () -> Void
    let onNotYet: () -> Void

    var body: some View {

        VStack(spacing: 12) {

            HStack(spacing: 12) {

                Image(systemName: "location.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)

                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {

                    Text("Looks like you made it!")
                        .font(.headline)

                    Text("Are you at \(destinationName)?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 12) {

                Button {
                    onNotYet()
                } label: {
                    Text("Not Yet")
                        .fontWeight(.semibold)
                        .frame(
                            maxWidth: .infinity
                        )
                }
                .buttonStyle(.bordered)

                Button {
                    onHere()
                } label: {
                    Label(
                        "I'm Here",
                        systemImage: "checkmark.circle.fill"
                    )
                    .fontWeight(.semibold)
                    .frame(
                        maxWidth: .infinity
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(
            .regularMaterial
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 18,
                style: .continuous
            )
        )
        .shadow(
            color: .black.opacity(0.18),
            radius: 12,
            x: 0,
            y: 5
        )
        .padding(.horizontal, 12)
    }
}
