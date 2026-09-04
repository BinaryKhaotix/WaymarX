//
//  SingleRowTileContainerView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/13/24.
//
import SwiftUI

struct SingleRowTileContainerView<Item: Identifiable, Content: View>: View {
    let title: String
    let items: [Item]
    let content: (Item) -> Content
    
    private let spacing: CGFloat = 10
    private let verticalPaddingForShadow: CGFloat = 10
    private let horizontalInset: CGFloat = 0          // keep aligned with card content
    private let clipCornerRadius: CGFloat = 14        // subtle, matches your inner chips
    private let tileSize: CGFloat = 110
    private let bottomPadding: CGFloat = 25
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            
            if !title.isEmpty {
                Text(title)
                    .font(.title2)
                    .bold()
                    .foregroundColor(Color("Dark Orange"))
            }
            GeometryReader { geo in
                
                ScrollView(.horizontal, showsIndicators: false) {

                    HStack(spacing: spacing) {

                        ForEach(items) { item in

                            content(item)
                                .frame(
                                    width: tileSize,
                                    height: tileSize
                                )
                        }
                    }
                    .padding(.bottom, 25)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
                .scrollIndicators(.hidden)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: clipCornerRadius,
                        style: .continuous
                    )
                )
                .contentShape(Rectangle())
            }
            .frame(height: tileSize + bottomPadding)
        }
    }
}
