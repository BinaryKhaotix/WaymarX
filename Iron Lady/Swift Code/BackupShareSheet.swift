//
//  BackupShareSheet.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/21/26.
//

import SwiftUI
import UIKit

struct BackupShareSheet: UIViewControllerRepresentable {

    let fileURL: URL

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {

        UIActivityViewController(
            activityItems: [fileURL],
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
        // Nothing needed here.
    }
}
