//
//  SettingsView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswordMismatchAlert = false
    @StateObject private var adMobConsentManager = AdMobConsentManager.shared

    var body: some View {
        Form {
            Section(header: Text("Account")) {
                Toggle("Stay Logged In", isOn: $isLoggedIn)

                Button("Logout") {
                    performLogout()
                }
                .foregroundColor(.red)
            }

            Section(header: Text("Change Password")) {
                SecureField("New Password", text: $password)
                SecureField("Confirm Password", text: $confirmPassword)

                Button("Update Password") {
                    handleChangePassword()
                }
                .disabled(password.isEmpty || confirmPassword.isEmpty)
            }
        }
        .navigationTitle("Settings")
        .alert(isPresented: $showPasswordMismatchAlert) {
            Alert(title: Text("Error"), message: Text("Passwords do not match."), dismissButton: .default(Text("OK")))
        }
    }

    private func handleChangePassword() {
        guard password == confirmPassword else {
            showPasswordMismatchAlert = true
            return
        }

        // Fetch user and update password in Core Data
        if let user = fetchUser() {
            user.password = password

            do {
                try user.managedObjectContext?.save()
                print("Password updated successfully.")
            } catch {
                print("Failed to update password: \(error.localizedDescription)")
            }
        }
    }

    private func fetchUser() -> CrumbUser? {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = CrumbUser.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "username == %@", loggedInUsername)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            print("Error fetching user: \(error.localizedDescription)")
            return nil
        }
    }

    private func performLogout() {
        isLoggedIn = false
        loggedInUsername = ""
        print("User logged out successfully.")
    }
}


//import SwiftUI
//
//struct SettingsView: View {
//    @EnvironmentObject var navigationModel: NavigationModel // For navigation
//    @Environment(\.managedObjectContext) private var viewContext // Core Data context
//    
//    @State private var currentPassword: String = ""
//    @State private var newPassword: String = ""
//    @State private var confirmPassword: String = ""
//    @State private var stayLoggedIn: Bool = false
//    @State private var showPasswordError: Bool = false
//    @State private var errorMessage: String = ""
//    @State private var showSuccessMessage: Bool = false
//
//    var body: some View {
//        VStack(spacing: 20) {
//            // Title
//            Text("Settings")
//                .font(.largeTitle)
//                .bold()
//                .padding()
//
//            // Password Change Section
//            VStack(alignment: .leading, spacing: 10) {
//                Text("Change Password")
//                    .font(.headline)
//
//                SecureField("Current Password", text: $currentPassword)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                SecureField("New Password", text: $newPassword)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                SecureField("Confirm New Password", text: $confirmPassword)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                if showPasswordError {
//                    Text(errorMessage)
//                        .font(.footnote)
//                        .foregroundColor(.red)
//                }
//
//                Button(action: updatePassword) {
//                    Text("Update Password")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.blue)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//            }
//            .padding()
//
//            // Stay Logged In Toggle
//            Toggle(isOn: $stayLoggedIn) {
//                Text("Stay Logged In")
//                    .font(.headline)
//            }
//            .padding()
//
//            Spacer()
//        }
//        .padding()
//        .navigationTitle("Settings")
//        .navigationBarTitleDisplayMode(.inline)
//        .alert(isPresented: $showSuccessMessage) {
//            Alert(
//                title: Text("Success"),
//                message: Text("Password updated successfully."),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//    }
//
//    // MARK: - Update Password Functionality
//    private func updatePassword() {
//        guard !currentPassword.isEmpty else {
//            showPasswordError = true
//            errorMessage = "Current password cannot be empty."
//            return
//        }
//
//        guard newPassword == confirmPassword else {
//            showPasswordError = true
//            errorMessage = "Passwords do not match."
//            return
//        }
//
//        guard newPassword.count >= 8 else {
//            showPasswordError = true
//            errorMessage = "New password must be at least 8 characters."
//            return
//        }
//
//        // Simulate password update (Replace with actual authentication logic)
//        // For now, assume currentPassword is always correct
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            showPasswordError = false
//            showSuccessMessage = true
//
//            // Clear fields after update
//            currentPassword = ""
//            newPassword = ""
//            confirmPassword = ""
//        }
//    }
//}
//
