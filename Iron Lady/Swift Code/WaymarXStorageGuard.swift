//
//  WaymarXStorageGuard.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/24/26.
//


import Foundation

enum WaymarXStorageGuard {

    static func verifyAvailableSpace(
        forArchive archiveURL: URL,
        additionalBytes: Int64 = 0
    ) throws {

        let attributes = try FileManager.default
            .attributesOfItem(atPath: archiveURL.path)

        let archiveBytes = (
            attributes[.size] as? NSNumber
        )?.int64Value ?? 0

        guard archiveBytes > 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "The selected backup archive is empty."
            )
        }

        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let values = try documents.resourceValues(
            forKeys: [
                .volumeAvailableCapacityForImportantUsageKey
            ]
        )

        guard let available = values
            .volumeAvailableCapacityForImportantUsage else {

            throw WaymarXRestoreError.invalidBackup(
                "Unable to determine available device storage."
            )
        }

        // Conservative first-pass estimate:
        // 4 times the compressed archive size,
        // plus 512 MB of working-space reserve.
        let reserve: Int64 = 512 * 1024 * 1024

        let (archiveAllowance, multipliedOverflow) =
            archiveBytes.multipliedReportingOverflow(by: 4)

        guard !multipliedOverflow,
              additionalBytes >= 0 else {
            throw WaymarXRestoreError.invalidBackup(
                "Invalid storage requirement."
            )
        }

        let (subtotal, firstOverflow) =
            archiveAllowance.addingReportingOverflow(
                additionalBytes
            )

        let (required, secondOverflow) =
            subtotal.addingReportingOverflow(reserve)

        guard !firstOverflow, !secondOverflow else {
            throw WaymarXRestoreError.invalidBackup(
                "Storage requirement exceeds supported limits."
            )
        }

        guard available >= required else {

            let formatter = ByteCountFormatter()
            formatter.countStyle = .file

            let neededText = formatter.string(
                fromByteCount: required
            )

            let availableText = formatter.string(
                fromByteCount: available
            )

            throw WaymarXRestoreError.invalidBackup(
                """
                Insufficient storage for safe restoration.

                Required estimate: \(neededText)
                Available: \(availableText)

                Free additional space and try again.
                """
            )
        }

        print("✅ WaymarX storage preflight passed")
        print("Archive size: \(archiveBytes) bytes")
        print("Estimated required: \(required) bytes")
        print("Available: \(available) bytes")
    }
}
