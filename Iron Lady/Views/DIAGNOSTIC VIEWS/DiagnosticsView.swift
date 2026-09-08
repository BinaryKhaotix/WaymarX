//
//  DiagnosticsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/4/26.
//

import SwiftUI
import UIKit

struct DiagnosticsView: View {

    @EnvironmentObject var diagnosticsStore:
        DiagnosticsStore
    

    var body: some View {

        ScrollView {

            LazyVStack(
                alignment: .leading,
                spacing: 18
            ) {

                systemStatusSection

                wantToGoSection

                eventLogSection
            }
            .padding()
        }

        .navigationTitle("Diagnostics")

        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItemGroup(
                placement:
                    .navigationBarTrailing
            ) {

                Button {

                    copyDiagnostics()

                } label: {

                    Image(
                        systemName:
                            "doc.on.doc"
                    )
                }

                Button(
                    role: .destructive
                ) {

                    diagnosticsStore.clear()

                } label: {

                    Image(
                        systemName:
                            "trash"
                    )
                }
            }
        }
    }


    // ============================================================
    // MARK: - System Status
    // ============================================================

    private var systemStatusSection:
        some View {

        DiagnosticSection(
            title: "System Status"
        ) {

            DiagnosticValueRow(
                title: "App State",
                value:
                    diagnosticsStore
                        .status
                        .appState
            )

            DiagnosticValueRow(
                title:
                    "Location Permission",
                value:
                    diagnosticsStore
                        .status
                        .locationAuthorization
            )

            DiagnosticValueRow(
                title:
                    "Notifications",
                value:
                    diagnosticsStore
                        .status
                        .notificationAuthorization
            )

            if let latitude =
                diagnosticsStore
                    .status
                    .latitude,
               let longitude =
                diagnosticsStore
                    .status
                    .longitude {

                DiagnosticValueRow(
                    title:
                        "Current Location",
                    value:
                        String(
                            format:
                                "%.6f, %.6f",
                            latitude,
                            longitude
                        )
                )
            }

            if let accuracy =
                diagnosticsStore
                    .status
                    .horizontalAccuracy {

                DiagnosticValueRow(
                    title:
                        "Location Accuracy",
                    value:
                        accuracyText(
                            accuracy
                        )
                )
            }

            DiagnosticValueRow(
                title:
                    "Last Location",
                value:
                    formattedDate(
                        diagnosticsStore
                            .status
                            .lastLocationUpdate
                    )
            )

            DiagnosticValueRow(
                title:
                    "Fallback Monitor",
                value:
                    diagnosticsStore
                        .status
                        .fallbackRunning
                    ? "Running"
                    : "Stopped"
            )

            if let error =
                diagnosticsStore
                    .status
                    .lastError {

                DiagnosticValueRow(
                    title:
                        "Last Error",
                    value:
                        error
                )
            }
        }
    }


    // ============================================================
    // MARK: - Want To Go
    // ============================================================

    private var wantToGoSection:
        some View {

        DiagnosticSection(
            title:
                "Want To Go Monitoring"
        ) {

            DiagnosticValueRow(
                title:
                    "Want To Go Pins",
                value:
                    "\(diagnosticsStore.status.wantToGoCount)"
            )

            DiagnosticValueRow(
                title:
                    "Active Geofences",
                value:
                    "\(diagnosticsStore.status.activeGeofenceCount)"
            )

            if diagnosticsStore
                .status
                .geofences
                .isEmpty {

                Text(
                    "No active geofences."
                )
                .font(.subheadline)
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    diagnosticsStore
                        .status
                        .geofences
                ) { geofence in

                    Divider()

                    VStack(
                        alignment: .leading,
                        spacing: 7
                    ) {

                        Text(
                            geofence.name
                        )
                        .font(
                            .headline
                        )

                        DiagnosticValueRow(
                            title:
                                "Radius",
                            value:
                                "\(Int(geofence.radius.rounded())) m (\(Int((geofence.radius * 3.28084).rounded())) ft)"
                        )
                        
                        DiagnosticValueRow(
                            title:
                                "Distance",
                            value:
                                distanceText(
                                    geofence.distance
                                )
                        )
                        
                        DiagnosticValueRow(
                            title:
                                "State",
                            value:
                                geofence.state
                        )
                    }
                }
            }

            if let event =
                diagnosticsStore
                    .status
                    .lastGeofenceEvent {

                Divider()

                DiagnosticValueRow(
                    title:
                        "Last Event",
                    value:
                        event
                )
            }

            if let arrival =
                diagnosticsStore
                    .status
                    .lastArrivalDetected {

                DiagnosticValueRow(
                    title:
                        "Last Arrival",
                    value:
                        arrival
                )
            }

            if let notification =
                diagnosticsStore
                    .status
                    .lastNotificationSent {

                DiagnosticValueRow(
                    title:
                        "Last Notification",
                    value:
                        notification
                )
            }
        }
    }


    // ============================================================
    // MARK: - Event Log
    // ============================================================

    private var eventLogSection:
        some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text("Recent Events")
                .font(
                    .title3.bold()
                )

            if diagnosticsStore
                .entries
                .isEmpty {

                Text(
                    "No diagnostics yet."
                )
                .foregroundStyle(
                    .secondary
                )

            } else {

                ForEach(
                    diagnosticsStore
                        .entries
                        .reversed()
                ) { entry in

                    DiagnosticRow(
                        entry: entry
                    )
                }
            }
        }
    }


    // ============================================================
    // MARK: - Helpers
    // ============================================================

    private func accuracyText(
        _ accuracy: Double
    ) -> String {

        if accuracy < 0 {
            return "Invalid"
        }

        let feet =
            accuracy * 3.28084

        return
            "\(Int(accuracy.rounded())) m (\(Int(feet.rounded())) ft)"
    }

    private func distanceText(
        _ distance: Double?
    ) -> String {

        guard let distance
        else {
            return "Unknown"
        }

        if distance < 1000 {

            let feet =
                distance * 3.28084

            return
                "\(Int(distance.rounded())) m (\(Int(feet.rounded())) ft)"
        }

        let kilometers =
            distance / 1000

        let miles =
            distance / 1609.344

        return String(
            format:
                "%.2f km (%.2f mi)",
            kilometers,
            miles
        )
    }

    private func formattedDate(
        _ date: Date?
    ) -> String {

        guard let date
        else {
            return "Never"
        }

        return date.formatted(
            date: .omitted,
            time: .standard
        )
    }


    private func copyDiagnostics() {

        var text = """
        WAYMARX DIAGNOSTICS

        SYSTEM STATUS
        App State: \(diagnosticsStore.status.appState)
        Location Permission: \(diagnosticsStore.status.locationAuthorization)
        Notifications: \(diagnosticsStore.status.notificationAuthorization)
        """

        if let latitude =
            diagnosticsStore
                .status
                .latitude,
           let longitude =
            diagnosticsStore
                .status
                .longitude {

            text += """

            Current Location: \(latitude), \(longitude)
            """
        }

        if let accuracy =
            diagnosticsStore
                .status
                .horizontalAccuracy {

            text += """

            Accuracy: \(accuracyText(accuracy))
            """
        }

        text += """


        WANT TO GO
        Pins: \(diagnosticsStore.status.wantToGoCount)
        Active Geofences: \(diagnosticsStore.status.activeGeofenceCount)
        """

        for geofence in
            diagnosticsStore
                .status
                .geofences {

            text += """


            \(geofence.name)
            Radius: \(Int(geofence.radius)) m
            Distance: \(distanceText(geofence.distance))
            State: \(geofence.state)
            """
        }

        text += """


        RECENT EVENTS
        """

        for entry in
            diagnosticsStore
                .entries
                .suffix(100) {

            text += """


            [\(entry.category)] \(entry.timestamp.formatted(date: .omitted, time: .standard))
            \(entry.message)
            """
        }

        UIPasteboard.general.string =
            text
    }
}


// ============================================================
// MARK: - Section Card
// ============================================================

private struct DiagnosticSection<
    Content: View
>: View {

    let title: String

    @ViewBuilder
    let content: Content

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            Text(title)
                .font(
                    .title3.bold()
                )

            VStack(
                alignment: .leading,
                spacing: 9
            ) {

                content
            }
            .padding(14)
            .background(
                Color(
                    .secondarySystemGroupedBackground
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
        }
    }
}


// ============================================================
// MARK: - Value Row
// ============================================================

private struct DiagnosticValueRow:
    View {

    let title: String
    let value: String

    var body: some View {

        HStack(
            alignment: .top
        ) {

            Text(title)
                .font(
                    .subheadline
                )
                .foregroundStyle(
                    .secondary
                )

            Spacer()

            Text(value)
                .font(
                    .subheadline
                        .weight(
                            .semibold
                        )
                )
                .multilineTextAlignment(
                    .trailing
                )
                .textSelection(
                    .enabled
                )
        }
    }
}


// ============================================================
// MARK: - Event Row
// ============================================================

private struct DiagnosticRow:
    View {

    let entry:
        DiagnosticsEntry

    private var timeText:
        String {

        entry.timestamp
            .formatted(
                date: .omitted,
                time: .standard
            )
    }

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 5
        ) {

            HStack {

                Text(
                    entry.category
                )
                .font(
                    .caption
                        .weight(
                            .semibold
                        )
                )

                Spacer()

                Text(
                    timeText
                )
                .font(
                    .caption2
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Text(
                entry.message
            )
            .font(
                .subheadline
            )
            .textSelection(
                .enabled
            )
        }
        .padding(12)
        .background(
            Color(
                .secondarySystemGroupedBackground
            )
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
    }
}
