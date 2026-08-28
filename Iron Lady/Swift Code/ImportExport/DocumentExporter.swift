//
//  DocumentExporter.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/27/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct DocumentExporter: UIViewControllerRepresentable {

    let url: URL
    let onFinished: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinished: onFinished)
    }

    func makeUIViewController(
        context: Context
    ) -> UIDocumentPickerViewController {

        let picker =
            UIDocumentPickerViewController(
                forExporting: [url],
                asCopy: true
            )

        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: Context
    ) {
    }

    final class Coordinator:
        NSObject,
        UIDocumentPickerDelegate {

        let onFinished: () -> Void

        init(
            onFinished: @escaping () -> Void
        ) {
            self.onFinished = onFinished
        }

        func documentPickerWasCancelled(
            _ controller: UIDocumentPickerViewController
        ) {
            onFinished()
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            onFinished()
        }
    }
}
