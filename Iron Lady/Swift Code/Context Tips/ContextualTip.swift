//
//  ContextualTip.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/3/26.
//

import Foundation

struct ContextualTip: Identifiable, Equatable {

    enum PresentationStyle {
        case banner
        case popover
        case sheet
    }

    let id: String
    let title: String
    let message: String
    let systemImage: String
    let presentationStyle: PresentationStyle
}

extension ContextualTip {

    static let arrivalNotificationActions =
        ContextualTip(
            id: "arrivalNotificationActions",
            title: "Arrival Notification Tip",
            message: "Press and hold an arrival notification to reveal the I'm Here and Not Yet buttons.",
            systemImage: "hand.tap.fill",
            presentationStyle: .banner
        )

    static let wantToGoPromotion =
        ContextualTip(
            id: "wantToGoPromotion",
            title: "Want To Go Tip",
            message: "You can manually promote a Want To Go pin from its detail page if arrival detection misses it.",
            systemImage: "mappin.and.ellipse",
            presentationStyle: .banner
        )
    
    static let backupRestore =
        ContextualTip(
            id: "backupRestore",
            title: "Backup & Restore",
            message: """
            Backup creates a file containing your Crumbz data so you can keep a copy somewhere safe.

            Restore loads data from a previously created backup file.

            Be sure to keep your backup file somewhere you can find it later.
            """,
            systemImage: "externaldrive.fill",
            presentationStyle: .banner
        )

    static let unsavedPins =
        ContextualTip(
            id: "unsavedPins",
            title: "Unsaved Pins",
            message: """
            Unsaved Pins are locations you've dropped but haven't named or organized yet.

            The location is still stored.

            Open an Unsaved Pin to give it a name, add details, assign it to a Group, or finish organizing it.
            """,
            systemImage: "mappin.circle.fill",
            presentationStyle: .banner
        )
}


