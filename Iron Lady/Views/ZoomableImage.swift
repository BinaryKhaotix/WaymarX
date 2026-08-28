//
//  ZoomableImage.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//

import SwiftUI

struct ZoomableImage: View {
    let image: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                },
                            DragGesture()
                                .onChanged { gesture in
                                    offset = CGSize(
                                        width: lastOffset.width + gesture.translation.width,
                                        height: lastOffset.height + gesture.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        resetImage()
                    }
                    .animation(.easeInOut, value: scale)
                    .animation(.easeInOut, value: offset)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .overlay(
                        Text("No Image Available")
                            .font(.headline)
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Stretch to parent size
    }

    private func resetImage() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
}



//import SwiftUI
//
//struct ZoomableImage: View {
//    let image: UIImage
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//    @State private var offset: CGSize = .zero
//    @State private var lastOffset: CGSize = .zero
//
//    var body: some View {
//        GeometryReader { geometry in
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .scaleEffect(scale)
//                .offset(x: offset.width, y: offset.height)
//                .gesture(
//                    SimultaneousGesture(
//                        MagnificationGesture()
//                            .onChanged { value in
//                                scale = lastScale * value
//                            }
//                            .onEnded { _ in
//                                lastScale = scale
//                            },
//                        DragGesture()
//                            .onChanged { gesture in
//                                offset = CGSize(
//                                    width: lastOffset.width + gesture.translation.width,
//                                    height: lastOffset.height + gesture.translation.height
//                                )
//                            }
//                            .onEnded { _ in
//                                lastOffset = offset
//                            }
//                    )
//                )
//                .onTapGesture(count: 2) {
//                    resetImage()
//                }
//                .animation(.easeInOut, value: scale)
//                .animation(.easeInOut, value: offset)
//        }
//    }
//
//    private func resetImage() {
//        scale = 1.0
//        lastScale = 1.0
//        offset = .zero
//        lastOffset = .zero
//    }
//}



//import SwiftUI
//
//struct ZoomableImage: View {
//    let image: UIImage
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//    @State private var offset: CGSize = .zero
//    @State private var lastOffset: CGSize = .zero
//
//    var body: some View {
//        GeometryReader { geometry in
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .scaleEffect(scale)
//                .offset(x: offset.width, y: offset.height)
//                .gesture(
//                    SimultaneousGesture(
//                        MagnificationGesture()
//                            .onChanged { value in
//                                scale = lastScale * value
//                            }
//                            .onEnded { _ in
//                                lastScale = scale
//                            },
//                        DragGesture()
//                            .onChanged { gesture in
//                                offset = CGSize(
//                                    width: lastOffset.width + gesture.translation.width,
//                                    height: lastOffset.height + gesture.translation.height
//                                )
//                            }
//                            .onEnded { _ in
//                                lastOffset = offset
//                            }
//                    )
//                )
//                .animation(.easeInOut, value: scale)
//        }
//    }
//}



//import SwiftUI
//
//struct ZoomableImage: View {
//    let image: UIImage
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//
//    var body: some View {
//        GeometryReader { geometry in
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .scaleEffect(scale)
//                .gesture(
//                    MagnificationGesture()
//                        .onChanged { value in
//                            scale = lastScale * value
//                        }
//                        .onEnded { _ in
//                            lastScale = scale
//                        }
//                )
//                .animation(.easeInOut, value: scale)
//        }
//    }
//}


//import SwiftUI
//
//struct ZoomableImage: View {
//    let image: UIImage
//    @State private var scale: CGFloat = 1.0
//    @State private var lastScale: CGFloat = 1.0
//
//    var body: some View {
//        GeometryReader { geometry in
//            Image(uiImage: image)
//                .resizable()
//                .scaledToFit()
//                .frame(width: geometry.size.width, height: geometry.size.height)
//                .scaleEffect(scale)
//                .gesture(
//                    MagnificationGesture()
//                        .onChanged { value in
//                            scale = lastScale * value
//                        }
//                        .onEnded { _ in
//                            lastScale = scale
//                        }
//                )
//                .animation(.easeInOut, value: scale)
//        }
//    }
//}
