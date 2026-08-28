//
//  BackupDocumentExporter.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/26/26.
//

import SwiftUI
import UIKit

struct BackupDocumentExporter: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {

        let picker = UIDocumentPickerViewController(
            forExporting: [fileURL],
            asCopy: true
        )

        picker.shouldShowFileExtensions = true

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {
    }
}
