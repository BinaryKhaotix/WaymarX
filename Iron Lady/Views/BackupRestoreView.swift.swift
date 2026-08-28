//
//  BackupRestoreView.swift.swift
//  Iron Lady
//
//  Created by Dino Grillo on 8/21/26.
//

import SwiftUI

struct BackupRestoreView: View {
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showBackupComingSoon = false
    @State private var showRestoreComingSoon = false
    
    var body: some View {
        NavigationStack {
            Form {
                
                // MARK: - Backup
                
                Section {
                    Button {
                        showBackupComingSoon = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Back Up Now")
                                    .foregroundStyle(.primary)
                                
                                Text("Create a complete backup of your WaymarX data.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "externaldrive.badge.icloud")
                                .foregroundStyle(.blue)
                        }
                    }
                    
                } header: {
                    Text("WaymarX Backup")
                } footer: {
                    Text(
                        "Backups will include your pins, groups, notes, " +
                        "locations, favorites, photos, and related data."
                    )
                }
                
                
                // MARK: - Last Backup
                
                Section("Last Backup") {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("No Backup Yet")
                                .foregroundStyle(.primary)
                            
                            Text("Your most recent backup will appear here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                
                // MARK: - Restore
                
                Section {
                    Button {
                        showRestoreComingSoon = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Restore From Backup")
                                    .foregroundStyle(.primary)
                                
                                Text("Restore WaymarX from a saved backup file.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.counterclockwise.icloud")
                                .foregroundStyle(.orange)
                        }
                    }
                    
                } header: {
                    Text("Restore")
                } footer: {
                    Text(
                        "A backup will be verified before any existing " +
                        "WaymarX data is changed."
                    )
                }
                
                
                // MARK: - Future Safety Information
                
                Section("About Backups") {
                    Label(
                        "Backups are designed to restore the complete WaymarX database.",
                        systemImage: "info.circle"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Backup & Restore")
            .navigationBarTitleDisplayMode(.inline)
            
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            
            .alert(
                "Backup",
                isPresented: $showBackupComingSoon
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(
                    "The backup interface is ready. " +
                    "We'll connect the actual backup engine next."
                )
            }
            
            .alert(
                "Restore",
                isPresented: $showRestoreComingSoon
            ) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(
                    "The restore interface is ready. " +
                    "We'll connect backup-file selection and validation next."
                )
            }
        }
    }
}

#Preview {
    BackupRestoreView()
}
