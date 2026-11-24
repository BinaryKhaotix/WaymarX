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

    // Optional so existing backup exports continue working.
    var onCompletion: ((Bool) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {

        let picker = UIDocumentPickerViewController(
            forExporting: [fileURL],
            asCopy: true
        )

        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {

        let onCompletion: ((Bool) -> Void)?

        init(onCompletion: ((Bool) -> Void)?) {
            self.onCompletion = onCompletion
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            print("✅ WaymarX recovery copy exported")

            // The document picker completed its export.
            // Cloud synchronization may still be pending.
            onCompletion?(true)
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            print("🟡 WaymarX recovery export cancelled")
            onCompletion?(false)
        }
    }
}

