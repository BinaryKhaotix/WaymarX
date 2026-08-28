//
//  AddUserView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//

import SwiftUI
import CoreData

struct AddUserView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    @State private var homeLatitude: String = ""
    @State private var homeLongitude: String = ""
    @State private var profilePicture: UIImage?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Details")) {
                    TextField("Username", text: $username)
                        .autocapitalization(.none) // Disable automatic capitalization
                        .textInputAutocapitalization(.never) // Required for iOS 15+
                        .disableAutocorrection(true)
                    SecureField("Password", text: $password)
                    TextField("Name", text: $name)
                    TextField("Address", text: $address)
                    TextField("Phone Number", text: $phoneNumber)
                    TextField("Home Latitude", text: $homeLatitude)
                    TextField("Home Longitude", text: $homeLongitude)
                }

                // Save Button
                Button("Save User") {
                    saveUser()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundColor(.white)
                .padding()
                .background(Color("Dark Blue"))
                .cornerRadius(10)
            }
            .navigationTitle("Add User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }

    private func saveUser() {
        let newUser = CrumbUser(context: viewContext)
        newUser.username = username
        newUser.password = password
        newUser.name = name
        newUser.address = address
        newUser.phoneNumber = phoneNumber
        newUser.homeLatitude = Double(homeLatitude) ?? 0.0
        newUser.homeLongitude = Double(homeLongitude) ?? 0.0

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Failed to save user: \(error.localizedDescription)")
        }
    }
}
