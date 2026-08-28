//
//  WaymarXBackupType.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/26/26.
//

import UniformTypeIdentifiers

extension UTType {
    static let waymarXBackup = UTType(
        exportedAs: "com.freedomautomation.waymarx.backup",
        conformingTo: .data
    )
}
