//
//  EditProfileView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/20/24.
//
import SwiftUI
import CoreLocation
import CoreData

struct EditProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationModel: NavigationModel

    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: [])
    private var users: FetchedResults<CrumbUser>

    @FetchRequest(
        entity: CrmGroup.entity(),
        sortDescriptors: [NSSortDescriptor(key: "groupName", ascending: true)]
    )
    private var groups: FetchedResults<CrmGroup>

    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""

    // ✅ App-wide appearance override (System / Light / Dark)
    @AppStorage("appColorScheme") private var appColorScheme: String = "system"
    @AppStorage("lastWaymarXBackupDate")
    private var lastWaymarXBackupDate: Double = 0

    @State private var selectedImage: UIImage?
    @State private var showCamera = false

    @State private var username = ""
    @State private var fullName = ""
    @State private var address = ""
    @State private var phoneNumber = ""
    @State private var latitude = ""
    @State private var longitude = ""

    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswordMismatchAlert = false

    @State private var selectedGroup: CrmGroup? = nil
    @State private var groupToEdit: CrmGroup? = nil
    @State private var showAddGroupSheet: Bool = false
    
    @State private var showBackupPlaceholder = false
    @State private var showRestorePlaceholder = false
    @State private var backupAlertMessage: String?
    @State private var backupFileURL: URL?
    @State private var showBackupShareSheet = false
    @State private var showRestoreFilePicker = false
    @State private var showBackupExporter = false
    
    @StateObject private var adMobConsentManager = AdMobConsentManager.shared

    private var user: CrumbUser? { users.first }

    private var preferredScheme: ColorScheme? {
        switch appColorScheme {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil // system
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            Text("Update your profile details and preferences.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 16) {

                    // ✅ Appearance toggle (System / Light / Dark)
                    AppearanceSection(appColorScheme: $appColorScheme)

                    ProfilePictureSection(
                        selectedImage: $selectedImage,
                        showCamera: $showCamera,
                        username: username
                    )

                    UserInformationSection(
                        username: $username,
                        fullName: $fullName,
                        address: $address,
                        phoneNumber: $phoneNumber
                    )

                    LocationSection(
                        latitude: $latitude,
                        longitude: $longitude,
                        onSetHomeLocation: setHomeLocation
                    )

                    GroupsManagementSection(
                        groups: groups,
                        selectedGroup: $selectedGroup,
                        onAddGroup: { showAddGroupSheet = true },
                        onEditSelectedGroup: {
                            if let g = selectedGroup { groupToEdit = g }
                        }
                    )

                    BackupRestoreSection(
                        onBackup: {
                            do {
                                let result =
                                    try BackupManager.shared.createBackupArchive(
                                        context: viewContext
                                    )

                                backupFileURL = result.fileURL
                                showBackupExporter = true
                                lastWaymarXBackupDate = Date().timeIntervalSince1970

                                print("""
                                WaymarX Backup Created

                                Pins: \(result.pinCount)
                                Groups: \(result.groupCount)
                                Photo References: \(result.photoReferences)
                                Photos Copied: \(result.photosCopied)
                                Photos Missing: \(result.photosMissing)

                                File:
                                \(result.fileURL.path)
                                """)

                            } catch {

                                backupAlertMessage = """
                                Backup Failed

                                \(error.localizedDescription)
                                """
                            }
                        },
                        onRestore: {
                            showRestoreFilePicker = true
                        },
                        lastBackupDate:
                            lastWaymarXBackupDate > 0
                                ? Date(timeIntervalSince1970: lastWaymarXBackupDate)
                                : nil
                    )
                    if adMobConsentManager.privacyOptionsRequired {
                        
                        VStack(alignment: .leading, spacing: 12) {

                            Text("Privacy")
                                .font(.headline)
                                .foregroundStyle(Color("Dark Orange"))

                            Button {
                                Task {
                                    await adMobConsentManager.showPrivacyOptions()
                                }
                            } label: {
                                HStack(spacing: 12) {

                                    Image(systemName: "hand.raised.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Color("Dark Orange"))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Privacy Choices")
                                            .font(.headline)
                                            .foregroundStyle(.primary)

                                        Text("Review or change your advertising privacy choices.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .cardStyle()
                    }
//                    PasswordSection(
//                        password: $password,
//                        confirmPassword: $confirmPassword,
//                        isLoggedIn: $isLoggedIn,
//                        onChangePassword: handleChangePassword,
//                        onLogout: performLogout,
//                        onSaveChanges: saveChanges
//                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(preferredScheme) // ✅ overrides device setting when not "system"
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { navigationModel.path.removeLast() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage) { image in
                if let image = image {
                    saveProfileImage(image)
                }
            }
        }
        .sheet(isPresented: $showAddGroupSheet) {
            GroupEditorView(groupToEdit: nil)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(item: $groupToEdit) { group in
            GroupEditorView(groupToEdit: group)
                .environment(\.managedObjectContext, viewContext)
        }
//        .sheet(isPresented: $showBackupShareSheet) {
//
//            if let backupFileURL = backupFileURL {
//
//                BackupShareSheet(
//                    fileURL: backupFileURL
//                )
//            }
//        }
        .fileImporter(
            isPresented: $showRestoreFilePicker,
            allowedContentTypes: [.waymarXBackup],
            allowsMultipleSelection: false
        ) { result in

            switch result {

            case .success(let urls):

                guard let selectedURL = urls.first else {
                    backupAlertMessage =
                        "No backup file was selected."
                    return
                }

                print(
                    "Selected WaymarX Backup:",
                    selectedURL.path
                )

                backupAlertMessage =
                    "Backup file selected successfully."

            case .failure(let error):

                backupAlertMessage = """
                Could Not Open Backup

                \(error.localizedDescription)
                """
            }
        }
        .sheet(isPresented: $showBackupExporter) {

            if let backupFileURL = backupFileURL {

                BackupDocumentExporter(
                    fileURL: backupFileURL
                )
            }
        }
        .onAppear {
            loadUserData()
            if selectedGroup == nil { selectedGroup = groups.first }
        }
        .alert(isPresented: $showPasswordMismatchAlert) {
            Alert(
                title: Text("Error"),
                message: Text("Passwords do not match."),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(
            "Backup & Restore",
            isPresented: Binding(
                get: { backupAlertMessage != nil },
                set: {
                    if !$0 {
                        backupAlertMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                backupAlertMessage = nil
            }
        } message: {
            Text(backupAlertMessage ?? "")
        }
    }

    // MARK: - Helper Methods

    private func setHomeLocation() {
        locationManager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if let currentLocation = locationManager.currentLocation {
                latitude = String(format: "%.6f", currentLocation.latitude)
                longitude = String(format: "%.6f", currentLocation.longitude)
            }
        }
    }

    private func handleChangePassword() {
        guard password == confirmPassword else {
            showPasswordMismatchAlert = true
            return
        }

        if let user = user {
            user.password = password
            do {
                try viewContext.save()
                print("Password updated successfully.")
            } catch {
                print("Failed to update password: \(error.localizedDescription)")
            }
        }
    }

    private func performLogout() {
        isLoggedIn = false
        loggedInUsername = ""
        print("User logged out successfully.")
    }

    private func saveChanges() {
        let user = self.user ?? CrumbUser(context: viewContext)
        user.username = username
        user.name = fullName
        user.address = address
        user.phoneNumber = phoneNumber
        user.homeLatitude = Double(latitude) ?? 0.0
        user.homeLongitude = Double(longitude) ?? 0.0

        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
            user.profilePicture = imageData
        }

        do {
            try viewContext.save()
        } catch {
            print("Failed to save changes: \(error.localizedDescription)")
        }
    }

    private func saveProfileImage(_ image: UIImage) {
        selectedImage = image
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            user?.profilePicture = imageData
            try? viewContext.save()
        }
    }

    private func loadUserData() {
        if let user = user {
            username = user.username ?? ""
            fullName = user.name ?? ""
            address = user.address ?? ""
            phoneNumber = user.phoneNumber ?? ""
            latitude = String(user.homeLatitude)
            longitude = String(user.homeLongitude)
            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
                selectedImage = uiImage
            }
        }
    }
}

// MARK: - Appearance Section

private struct AppearanceSection: View {
    @Binding var appColorScheme: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Appearance")
                .font(.headline)
                .foregroundStyle(Color("Dark Orange"))

            Picker("Theme", selection: $appColorScheme) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)

            Text("Overrides your phone’s theme for this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}

// MARK: - Subviews

struct GroupsManagementSection: View {
    let groups: FetchedResults<CrmGroup>
    @Binding var selectedGroup: CrmGroup?

    let onAddGroup: () -> Void
    let onEditSelectedGroup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Groups")
                .font(.headline)
                .foregroundStyle(Color("Dark Orange"))

            if groups.isEmpty {
                Text("No groups yet.")
                    .foregroundStyle(.secondary)

                Button(action: onAddGroup) {
                    Text("+ Add Group")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("Dark Blue"))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            } else {
                Picker("Select group", selection: $selectedGroup) {
                    Text("Select...").tag(Optional<CrmGroup>.none)
                    ForEach(groups, id: \.objectID) { group in
                        Text(group.groupName ?? "Unnamed Group")
                            .tag(Optional(group))
                    }
                }
                .pickerStyle(.menu)

                if let g = selectedGroup {
                    let desc = (g.groupDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button(action: onAddGroup) {
                        Text("+ Add")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("Dark Blue"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }

                    Button(action: onEditSelectedGroup) {
                        Text("Edit")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("Dark Orange"))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(selectedGroup == nil)
                    .opacity(selectedGroup == nil ? 0.5 : 1.0)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Backup & Restore Section

struct BackupRestoreSection: View {

    let onBackup: () -> Void
    let onRestore: () -> Void
    let lastBackupDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Backup & Restore")
                .font(.headline)
                .foregroundStyle(Color("Dark Orange"))

            Text("Create a complete backup of your WaymarX pins, groups, photos, and related data.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(action: onBackup) {
                HStack(spacing: 12) {

                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.system(size: 20))
                        .foregroundStyle(Color("Dark Blue"))

                    VStack(alignment: .leading, spacing: 3) {

                        Text("Back Up WaymarX Data")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Save a complete copy of your WaymarX data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            Button(action: onRestore) {
                HStack(spacing: 12) {

                    Image(systemName: "arrow.counterclockwise.icloud")
                        .font(.system(size: 20))
                        .foregroundStyle(Color("Dark Orange"))

                    VStack(alignment: .leading, spacing: 3) {

                        Text("Restore From Backup")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Restore your pins, groups, photos, and related data.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "square.and.arrow.down")
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            HStack {

                Image(systemName: "clock")
                    .foregroundStyle(.secondary)

                Text("Last Backup")

                Spacer()

                if let lastBackupDate {
                    Text(
                        lastBackupDate.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .foregroundStyle(.secondary)
                } else {
                    Text("None")
                        .foregroundStyle(.secondary)
                }            }
            .font(.subheadline)
        }
        .cardStyle()
    }
}

struct ProfilePictureSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var showCamera: Bool
    var username: String

    var body: some View {
        VStack {
            HStack(spacing: 14) {
                ZStack(alignment: .bottomTrailing) {
                    Button(action: { showCamera = true }) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 92, height: 92)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 92, height: 92)
                                .foregroundStyle(.secondary)
                                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
                        }
                    }
                    .buttonStyle(.plain)

                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 30, height: 30)
                            .shadow(color: Color.black.opacity(0.18), radius: 3, x: 0, y: 2)

                        Image(systemName: "camera.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .offset(x: 4, y: 4)
                }

                Text(username.isEmpty ? "Username" : username)
                    .font(.title2)
                    .bold()
                    .foregroundStyle(Color("Dark Orange"))

                Spacer()
            }
        }
        .cardStyle()
    }
}

struct UserInformationSection: View {
    @Binding var username: String
    @Binding var fullName: String
    @Binding var address: String
    @Binding var phoneNumber: String

    var body: some View {
        VStack(spacing: 14) {
            inputField(title: "Username", text: $username)
            inputField(title: "Full Name", text: $fullName)
            inputField(title: "Address", text: $address)
            inputField(title: "Phone", text: $phoneNumber)
        }
        .cardStyle()
    }

    private func inputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color("Dark Orange"))

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct LocationSection: View {
    @Binding var latitude: String
    @Binding var longitude: String
    var onSetHomeLocation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Area/Trip Location")
                .font(.headline)
                .foregroundStyle(Color("Dark Orange"))

            Text("Latitude: \(latitude)")
                .foregroundStyle(.primary)
            Text("Longitude: \(longitude)")
                .foregroundStyle(.primary)

            Button(action: onSetHomeLocation) {
                Text("Use Current Location")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("Dark Orange"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .cardStyle()
    }
}

struct PasswordSection: View {
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var isLoggedIn: Bool
    var onChangePassword: () -> Void
    var onLogout: () -> Void
    var onSaveChanges: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            SecureField("New Password", text: $password)
                .textFieldStyle(.roundedBorder)

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            Button(action: onChangePassword) {
                Text("Update Password")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(password.isEmpty || confirmPassword.isEmpty ? Color.gray : Color("Dark Blue"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(password.isEmpty || confirmPassword.isEmpty)

            Divider()
                .padding(.vertical, 4)

            Button(action: onSaveChanges) {
                Text("Save Changes")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("Dark Blue"))
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .cardStyle()
    }
}

// MARK: - Card Style Helper

private extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color(.separator).opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 5)
    }
}



//import SwiftUI
//import CoreLocation
//import CoreData
//
//struct EditProfileView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: [])
//    private var users: FetchedResults<CrumbUser>
//
//    // ✅ Groups fetch
//    @FetchRequest(
//        entity: CrmGroup.entity(),
//        sortDescriptors: [NSSortDescriptor(key: "groupName", ascending: true)]
//    )
//    private var groups: FetchedResults<CrmGroup>
//
//    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
//    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""
//
//    @State private var selectedImage: UIImage?
//    @State private var showCamera = false
//
//    @State private var username = ""
//    @State private var fullName = ""
//    @State private var address = ""
//    @State private var phoneNumber = ""
//    @State private var latitude = ""
//    @State private var longitude = ""
//
//    @State private var password: String = ""
//    @State private var confirmPassword: String = ""
//    @State private var showPasswordMismatchAlert = false
//
//    // ✅ Group editor state
//    @State private var selectedGroup: CrmGroup? = nil
//    @State private var groupToEdit: CrmGroup? = nil
//    @State private var showAddGroupSheet: Bool = false
//
//    private var user: CrumbUser? {
//        users.first
//    }
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Update your profile details and preferences.")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Profile Picture Section
//                    ProfilePictureSection(
//                        selectedImage: $selectedImage,
//                        showCamera: $showCamera,
//                        username: username
//                    )
//
//                    // User Information Section
//                    UserInformationSection(
//                        username: $username,
//                        fullName: $fullName,
//                        address: $address,
//                        phoneNumber: $phoneNumber
//                    )
//
//                    // Location Section
//                    LocationSection(
//                        latitude: $latitude,
//                        longitude: $longitude,
//                        onSetHomeLocation: setHomeLocation
//                    )
//
//                    // ✅ NEW: Groups management section
//                    GroupsManagementSection(
//                        groups: groups,
//                        selectedGroup: $selectedGroup,
//                        onAddGroup: {
//                            showAddGroupSheet = true
//                        },
//                        onEditSelectedGroup: {
//                            if let g = selectedGroup {
//                                groupToEdit = g
//                            }
//                        }
//                    )
//
//                    // Password Section
//                    PasswordSection(
//                        password: $password,
//                        confirmPassword: $confirmPassword,
//                        isLoggedIn: $isLoggedIn,
//                        onChangePassword: handleChangePassword,
//                        onLogout: performLogout,
//                        onSaveChanges: saveChanges
//                    )
//                }
//                .padding(.horizontal)
//            }
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Edit Profile")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveProfileImage(image)
//                }
//            }
//        }
//
//        // ✅ Add Group (create new)
//        .sheet(isPresented: $showAddGroupSheet) {
//            GroupEditorView(groupToEdit: nil)
//                .environment(\.managedObjectContext, viewContext)
//        }
//
//        // ✅ Edit Group (existing)
//        .sheet(item: $groupToEdit) { group in
//            GroupEditorView(groupToEdit: group)
//                .environment(\.managedObjectContext, viewContext)
//        }
//
//        .onAppear {
//            loadUserData()
//            // Default selection: pick the first group if none selected
//            if selectedGroup == nil {
//                selectedGroup = groups.first
//            }
//        }
//        .alert(isPresented: $showPasswordMismatchAlert) {
//            Alert(
//                title: Text("Error"),
//                message: Text("Passwords do not match."),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//    }
//
//    // MARK: - Helper Methods
//    private func setHomeLocation() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            if let currentLocation = locationManager.currentLocation {
//                latitude = String(format: "%.6f", currentLocation.latitude)
//                longitude = String(format: "%.6f", currentLocation.longitude)
//            }
//        }
//    }
//
//    private func handleChangePassword() {
//        guard password == confirmPassword else {
//            showPasswordMismatchAlert = true
//            return
//        }
//
//        if let user = user {
//            user.password = password
//
//            do {
//                try viewContext.save()
//                print("Password updated successfully.")
//            } catch {
//                print("Failed to update password: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    private func performLogout() {
//        isLoggedIn = false
//        loggedInUsername = ""
//        print("User logged out successfully.")
//    }
//
//    private func saveChanges() {
//        let user = self.user ?? CrumbUser(context: viewContext)
//        user.username = username
//        user.name = fullName
//        user.address = address
//        user.phoneNumber = phoneNumber
//        user.homeLatitude = Double(latitude) ?? 0.0
//        user.homeLongitude = Double(longitude) ?? 0.0
//
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            user.profilePicture = imageData
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveProfileImage(_ image: UIImage) {
//        selectedImage = image
//        if let imageData = image.jpegData(compressionQuality: 0.8) {
//            user?.profilePicture = imageData
//            try? viewContext.save()
//        }
//    }
//
//    private func loadUserData() {
//        if let user = user {
//            username = user.username ?? ""
//            fullName = user.name ?? ""
//            address = user.address ?? ""
//            phoneNumber = user.phoneNumber ?? ""
//            latitude = String(user.homeLatitude)
//            longitude = String(user.homeLongitude)
//            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
//                selectedImage = uiImage
//            }
//        }
//    }
//}
//
//// MARK: - Subviews
//
//struct GroupsManagementSection: View {
//    let groups: FetchedResults<CrmGroup>
//    @Binding var selectedGroup: CrmGroup?
//
//    let onAddGroup: () -> Void
//    let onEditSelectedGroup: () -> Void
//
//    var body: some View {
//        Section {
//            VStack(alignment: .leading, spacing: 12) {
//                Text("Groups")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//
//                if groups.isEmpty {
//                    Text("No groups yet.")
//                        .foregroundColor(.gray)
//
//                    Button(action: onAddGroup) {
//                        Text("+ Add Group")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Blue"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                } else {
//                    Picker("Select group", selection: $selectedGroup) {
//                        Text("Select...").tag(Optional<CrmGroup>.none)
//                        ForEach(groups, id: \.objectID) { group in
//                            Text(group.groupName ?? "Unnamed Group")
//                                .tag(Optional(group))
//                        }
//                    }
//                    .pickerStyle(.menu)
//
//                    if let g = selectedGroup {
//                        let desc = (g.groupDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
//                        if !desc.isEmpty {
//                            Text(desc)
//                                .font(.subheadline)
//                                .foregroundColor(.gray)
//                        }
//                    }
//
//                    HStack(spacing: 10) {
//                        Button(action: onAddGroup) {
//                            Text("+ Add")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color("Dark Blue"))
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//
//                        Button(action: onEditSelectedGroup) {
//                            Text("Edit")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color("Dark Orange"))
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                        .disabled(selectedGroup == nil)
//                        .opacity(selectedGroup == nil ? 0.5 : 1.0)
//                    }
//                }
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct ProfilePictureSection: View {
//    @Binding var selectedImage: UIImage?
//    @Binding var showCamera: Bool
//    var username: String
//
//    var body: some View {
//        Section {
//            VStack {
//                HStack {
//                    ZStack(alignment: .bottomTrailing) {
//                        Button(action: { showCamera = true }) {
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 100, height: 100)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            } else {
//                                Image(systemName: "person.crop.circle.fill")
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 100, height: 100)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            }
//                        }
//                        .buttonStyle(PlainButtonStyle())
//
//                        ZStack {
//                            Circle()
//                                .fill(Color.blue)
//                                .frame(width: 30, height: 30)
//                                .shadow(radius: 3)
//
//                            Image(systemName: "camera.fill")
//                                .foregroundColor(.white)
//                                .font(.system(size: 15))
//                        }
//                        .offset(x: 5, y: 5)
//                    }
//
//                    Text(username.isEmpty ? "Username" : username)
//                        .font(.title)
//                        .bold()
//                        .foregroundColor(Color("Dark Orange"))
//                }
//            }
//        }
//        .padding()
//    }
//}
//
//struct UserInformationSection: View {
//    @Binding var username: String
//    @Binding var fullName: String
//    @Binding var address: String
//    @Binding var phoneNumber: String
//
//    var body: some View {
//        Section {
//            VStack(spacing: 15) {
//                inputField(title: "Username", text: $username)
//                inputField(title: "Full Name", text: $fullName)
//                inputField(title: "Address", text: $address)
//                inputField(title: "Phone", text: $phoneNumber)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//
//    private func inputField(title: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(title, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//}
//
//struct LocationSection: View {
//    @Binding var latitude: String
//    @Binding var longitude: String
//    var onSetHomeLocation: () -> Void
//
//    var body: some View {
//        Section {
//            VStack(alignment: .leading, spacing: 10) {
//                Text("Area/Trip Location")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//
//                Text("Latitude: \(latitude)")
//                Text("Longitude: \(longitude)")
//
//                Button(action: onSetHomeLocation) {
//                    Text("Use Current Location")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct PasswordSection: View {
//    @Binding var password: String
//    @Binding var confirmPassword: String
//    @Binding var isLoggedIn: Bool
//    var onChangePassword: () -> Void
//    var onLogout: () -> Void
//    var onSaveChanges: () -> Void
//
//    var body: some View {
//        Section {
//            VStack(spacing: 10) {
//                SecureField("New Password", text: $password)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                SecureField("Confirm Password", text: $confirmPassword)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                Button(action: onChangePassword) {
//                    Text("Update Password")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(password.isEmpty || confirmPassword.isEmpty ? Color.gray : Color("Dark Blue"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//                .disabled(password.isEmpty || confirmPassword.isEmpty)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//
//        Section {
//            Button(action: onSaveChanges) {
//                Text("Save Changes")
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color("Dark Blue"))
//                    .foregroundColor(.white)
//                    .cornerRadius(10)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}





//import SwiftUI
//import CoreLocation
//
//struct EditProfileView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: []) private var users: FetchedResults<CrumbUser>
//
//    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
//    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""
//
//    @State private var selectedImage: UIImage?
//    @State private var showCamera = false
//    @State private var username = ""
//    @State private var fullName = ""
//    @State private var address = ""
//    @State private var phoneNumber = ""
//    @State private var latitude = ""
//    @State private var longitude = ""
//    @State private var password: String = ""
//    @State private var confirmPassword: String = ""
//    @State private var showPasswordMismatchAlert = false
//
//    private var user: CrumbUser? {
//        users.first
//    }
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Update your profile details and preferences.")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Profile Picture Section
//                    ProfilePictureSection(
//                        selectedImage: $selectedImage,
//                        showCamera: $showCamera,
//                        username: username
//                    )
//
//                    // User Information Section
//                    UserInformationSection(
//                        username: $username,
//                        fullName: $fullName,
//                        address: $address,
//                        phoneNumber: $phoneNumber
//                    )
//
//                    // Location Section
//                    LocationSection(
//                        latitude: $latitude,
//                        longitude: $longitude,
//                        onSetHomeLocation: setHomeLocation
//                    )
//
//                    // Password Section
//                    PasswordSection(
//                        password: $password,
//                        confirmPassword: $confirmPassword,
//                        onChangePassword: handleChangePassword
//                    )
//
//                    // Account Actions Section
//                    AccountActionsSection(
//                        isLoggedIn: $isLoggedIn,
//                        onLogout: performLogout,
//                        onSaveChanges: saveChanges
//                    )
//                }
//                .padding(.horizontal)
//            }
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Edit Profile")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .onAppear {
//            loadUserData()
//        }
//        .alert(isPresented: $showPasswordMismatchAlert) {
//            Alert(
//                title: Text("Error"),
//                message: Text("Passwords do not match."),
//                dismissButton: .default(Text("OK"))
//            )
//        }
//    }
//
//    // MARK: - Helper Methods
//    private func setHomeLocation() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            if let currentLocation = locationManager.currentLocation {
//                latitude = String(format: "%.6f", currentLocation.latitude)
//                longitude = String(format: "%.6f", currentLocation.longitude)
//            }
//        }
//    }
//
//    private func handleChangePassword() {
//        guard password == confirmPassword else {
//            showPasswordMismatchAlert = true
//            return
//        }
//
//        if let user = user {
//            user.password = password
//
//            do {
//                try viewContext.save()
//                print("Password updated successfully.")
//            } catch {
//                print("Failed to update password: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    private func performLogout() {
//        isLoggedIn = false
//        loggedInUsername = ""
//        print("User logged out successfully.")
//    }
//
//    private func saveChanges() {
//        let user = self.user ?? CrumbUser(context: viewContext)
//        user.username = username
//        user.name = fullName
//        user.address = address
//        user.phoneNumber = phoneNumber
//        user.homeLatitude = Double(latitude) ?? 0.0
//        user.homeLongitude = Double(longitude) ?? 0.0
//
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            user.profilePicture = imageData
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func loadUserData() {
//        if let user = user {
//            username = user.username ?? ""
//            fullName = user.name ?? ""
//            address = user.address ?? ""
//            phoneNumber = user.phoneNumber ?? ""
//            latitude = String(user.homeLatitude)
//            longitude = String(user.homeLongitude)
//            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
//                selectedImage = uiImage
//            }
//        }
//    }
//}
//
//// MARK: - Subviews
//
//struct ProfilePictureSection: View {
//    @Binding var selectedImage: UIImage?
//    @Binding var showCamera: Bool
//    var username: String
//
//    var body: some View {
//        Section {
//            VStack {
//                HStack {
//                    ZStack(alignment: .bottomTrailing) {
//                        Button(action: { showCamera = true }) {
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 100, height: 100)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            } else {
//                                Image("defaultProfile")
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 100, height: 100)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            }
//                        }
//                        .buttonStyle(PlainButtonStyle()) // Removes default button styling
//
//                        // Clickable Indicator
//                        ZStack {
//                            Circle()
//                                .fill(Color.blue)
//                                .frame(width: 30, height: 30)
//                                .shadow(radius: 3)
//
//                            Image(systemName: "camera.fill")
//                                .foregroundColor(.white)
//                                .font(.system(size: 15))
//                        }
//                        .offset(x: 5, y: 5)
//                    }
//
//                    Text(username.isEmpty ? "Username" : username)
//                        .font(.title)
//                        .bold()
//                        .foregroundColor(Color("Dark Orange"))
//                        .frame(maxWidth: .infinity)
//                }
//
//                
//            }
//
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct UserInformationSection: View {
//    @Binding var username: String
//    @Binding var fullName: String
//    @Binding var address: String
//    @Binding var phoneNumber: String
//
//    var body: some View {
//        Section {
//            VStack(spacing: 15) {
//                inputField(title: "Username", text: $username)
//                inputField(title: "Full Name", text: $fullName)
//                inputField(title: "Address", text: $address)
//                inputField(title: "Phone", text: $phoneNumber)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//
//    private func inputField(title: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(title, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//}
//
//struct LocationSection: View {
//    @Binding var latitude: String
//    @Binding var longitude: String
//    var onSetHomeLocation: () -> Void
//
//    var body: some View {
//        Section {
//            VStack(alignment: .leading, spacing: 10) {
//                Text("Location")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//
//                Text("Latitude: \(latitude)")
//                Text("Longitude: \(longitude)")
//
//                Button(action: onSetHomeLocation) {
//                    Text("Set Home Location")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct PasswordSection: View {
//    @Binding var password: String
//    @Binding var confirmPassword: String
//    var onChangePassword: () -> Void
//
//    var body: some View {
//        Section {
//            VStack(spacing: 10) {
//                SecureField("New Password", text: $password)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                SecureField("Confirm Password", text: $confirmPassword)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                Button(action: onChangePassword) {
//                    Text("Update Password")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(password.isEmpty || confirmPassword.isEmpty ? Color.gray : Color("Dark Blue"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//                .disabled(password.isEmpty || confirmPassword.isEmpty)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct AccountActionsSection: View {
//    @Binding var isLoggedIn: Bool
//    var onLogout: () -> Void
//    var onSaveChanges: () -> Void
//
//    var body: some View {
//        Section {
//            VStack {
//                Toggle("Stay Logged In", isOn: $isLoggedIn)
//                
//                Button(action: onLogout) {
//                    Text("Logout")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color.red)
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//                
//                Button(action: onSaveChanges) {
//                    Text("Save Changes")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Blue"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                }
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct EditProfileView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Use shared LocationManager instance
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: []) private var users: FetchedResults<CrumbUser>
//
//    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
//    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""
//
//    @State private var selectedImage: UIImage?
//    @State private var showCamera = false
//    @State private var username = ""
//    @State private var fullName = ""
//    @State private var address = ""
//    @State private var phoneNumber = ""
//    @State private var latitude = ""
//    @State private var longitude = ""
//
//    // Password management
//    @State private var password: String = ""
//    @State private var confirmPassword: String = ""
//    @State private var showPasswordMismatchAlert = false
//
//    private var user: CrumbUser? {
//        users.first
//    }
//
//    var body: some View {
//        ZStack {
//            Color(.systemGroupedBackground).ignoresSafeArea()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Profile Picture Section
//                    VStack(spacing: 10) {
//                        HStack {
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 80, height: 80)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            } else {
//                                Image("defaultProfile")
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 80, height: 80)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            }
//
//                            Text(username.isEmpty ? "Username" : username)
//                                .font(.title2)
//                                .bold()
//                                .foregroundColor(Color("Dark Orange"))
//                        }
//
//                        Button(action: {
//                            showCamera = true
//                        }) {
//                            Text("Update Profile Picture")
//                                .foregroundColor(.blue)
//                                .underline()
//                        }
//                        .sheet(isPresented: $showCamera) {
//                            CameraView(selectedImage: $selectedImage) { image in
//                                if let image = image {
//                                    saveProfileImage(image)
//                                }
//                            }
//                        }
//                    }
//
//                    Divider()
//
//                    // Form Fields Section
//                    Group {
//                        formField(title: "Username", text: $username)
//                        formField(title: "Full Name", text: $fullName)
//                        formField(title: "Address", text: $address)
//                        formField(title: "Phone", text: $phoneNumber)
//                        formField(title: "Latitude", text: $latitude)
//                        formField(title: "Longitude", text: $longitude)
//                    }
//
//                    Button(action: setHomeLocation) {
//                        Text("Set Home Location")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Orange"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//
//                    Divider()
//
//                    // Password Change Section
//                    Section {
//                        SecureField("New Password", text: $password)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                        SecureField("Confirm Password", text: $confirmPassword)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                        Button(action: handleChangePassword) {
//                            Text("Update Password")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(password.isEmpty || confirmPassword.isEmpty ? Color.gray : Color("Dark Blue"))
//                                .foregroundColor(.white)
//                                .cornerRadius(10)
//                        }
//                        .disabled(password.isEmpty || confirmPassword.isEmpty)
//                    }
//
//                    Divider()
//
//                    // Stay Logged In Section
//                    Toggle("Stay Logged In", isOn: $isLoggedIn)
//
//                    // Logout Button
//                    Button(action: performLogout) {
//                        Text("Logout")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color.red)
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//
//                    Divider()
//
//                    // Save Changes Button
//                    Button(action: saveChanges) {
//                        Text("Save Changes")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Blue"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                }
//                .padding()
//            }
//        }
//        .onAppear {
//            loadUserData()
//        }
//        .navigationTitle("Edit Profile")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: { navigationModel.path.removeLast() }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//
//        .alert(isPresented: $showPasswordMismatchAlert) {
//            Alert(title: Text("Error"), message: Text("Passwords do not match."), dismissButton: .default(Text("OK")))
//        }
//    }
//
//    private func formField(title: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(title, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//
//    private func loadUserData() {
//        if let user = user {
//            username = user.username ?? ""
//            fullName = user.name ?? ""
//            address = user.address ?? ""
//            phoneNumber = user.phoneNumber ?? ""
//            latitude = String(user.homeLatitude)
//            longitude = String(user.homeLongitude)
//            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
//                selectedImage = uiImage
//            }
//        }
//    }
//
//    private func saveChanges() {
//        let user = self.user ?? CrumbUser(context: viewContext)
//        user.username = username
//        user.name = fullName
//        user.address = address
//        user.phoneNumber = phoneNumber
//        user.homeLatitude = Double(latitude) ?? 0.0
//        user.homeLongitude = Double(longitude) ?? 0.0
//
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            user.profilePicture = imageData
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveProfileImage(_ image: UIImage) {
//        selectedImage = image
//        if let imageData = image.jpegData(compressionQuality: 0.8) {
//            user?.profilePicture = imageData
//            try? viewContext.save()
//        }
//    }
//
//    private func setHomeLocation() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            if let currentLocation = locationManager.currentLocation {
//                latitude = String(format: "%.6f", currentLocation.latitude)
//                longitude = String(format: "%.6f", currentLocation.longitude)
//            }
//        }
//    }
//
//    private func handleChangePassword() {
//        guard password == confirmPassword else {
//            showPasswordMismatchAlert = true
//            return
//        }
//
//        if let user = user {
//            user.password = password
//
//            do {
//                try viewContext.save()
//                print("Password updated successfully.")
//            } catch {
//                print("Failed to update password: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    private func performLogout() {
//        isLoggedIn = false
//        loggedInUsername = ""
//        print("User logged out successfully.")
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct EditProfileView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Use shared LocationManager instance
//    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: []) private var users: FetchedResults<CrumbUser>
//
//    @State private var selectedImage: UIImage?
//    @State private var showCamera = false
//    @State private var username = ""
//    @State private var fullName = ""
//    @State private var address = ""
//    @State private var phoneNumber = ""
//    @State private var latitude = ""
//    @State private var longitude = ""
//
//    private var user: CrumbUser? {
//        users.first
//    }
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Profile Picture and Name
//                    HStack {
//                        if let image = selectedImage {
//                            Image(uiImage: image)
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 80, height: 80)
//                                .clipShape(Circle())
//                                .shadow(radius: 5)
//                        } else {
//                            Image("defaultProfile")
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 80, height: 80)
//                                .clipShape(Circle())
//                                .shadow(radius: 5)
//                        }
//
//                        Text(username.isEmpty ? "Username" : username)
//                            .font(.title2)
//                            .bold()
//                            .foregroundColor(Color("Dark Orange"))
//                    }
//
//                    Divider()
//
//                    // Camera to Update Profile Picture
//                    Button(action: {
//                        showCamera = true
//                    }) {
//                        Text("Update Profile Picture")
//                            .foregroundColor(.blue)
//                            .underline()
//                    }
//                    .sheet(isPresented: $showCamera) {
//                        CameraView(selectedImage: $selectedImage) { image in
//                            if let image = image {
//                                saveProfileImage(image)
//                            }
//                        }
//                    }
//
//                    // Form Fields
//                    Group {
//                        formField(title: "Username", text: $username)
//                        formField(title: "Full Name", text: $fullName)
//                        formField(title: "Address", text: $address)
//                        formField(title: "Phone", text: $phoneNumber)
//                        formField(title: "Latitude", text: $latitude)
//                        formField(title: "Longitude", text: $longitude)
//                    }
//
//                    // Set Home Location Button
//                    Button(action: setHomeLocation) {
//                        Text("Set Home Location")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Orange"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//
//                    Button(action: saveChanges) {
//                        Text("Save Changes")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Blue"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                }
//                .padding()
//            }
//        }
//        .onAppear {
//            loadUserData()
//        }
//        .navigationTitle("Edit Profile")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func formField(title: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(title, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//
//    // MARK: - Load User Data
//    private func loadUserData() {
//        if let user = user {
//            username = user.username ?? ""
//            fullName = user.name ?? ""
//            address = user.address ?? ""
//            phoneNumber = user.phoneNumber ?? ""
//            latitude = String(user.homeLatitude)
//            longitude = String(user.homeLongitude)
//            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
//                selectedImage = uiImage
//            }
//        }
//    }
//
//    // MARK: - Save Changes
//    private func saveChanges() {
//        let user = self.user ?? CrumbUser(context: viewContext)
//        user.username = username
//        user.name = fullName
//        user.address = address
//        user.phoneNumber = phoneNumber
//
//        // Validate and save latitude and longitude as strings
//        user.homeLatitude = Double(latitude) ?? 0.0
//        user.homeLongitude = Double(longitude) ?? 0.0
//
//        // Save profile picture if available
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            user.profilePicture = imageData
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveProfileImage(_ image: UIImage) {
//        selectedImage = image
//        if let imageData = image.jpegData(compressionQuality: 0.8) {
//            user?.profilePicture = imageData
//            try? viewContext.save()
//        }
//    }
//
//    // MARK: - Set Home Location
//    private func setHomeLocation() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { // Small delay to allow location updates
//            if let currentLocation = locationManager.currentLocation {
//                latitude = String(format: "%.6f", currentLocation.latitude)
//                longitude = String(format: "%.6f", currentLocation.longitude)
//                print("Location set: \(latitude), \(longitude)")
//            } else {
//                print("Failed to fetch current location.")
//            }
//        }
//    }
//}


//import SwiftUI
//
//struct EditProfileView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @FetchRequest(entity: CrumbUser.entity(), sortDescriptors: []) private var users: FetchedResults<CrumbUser>
//
//    @State private var selectedImage: UIImage?
//    @State private var showCamera = false
//    @State private var username = ""
//    @State private var fullName = ""
//    @State private var address = ""
//    @State private var phoneNumber = ""
//    @State private var latitude = ""
//    @State private var longitude = ""
//
//    private var user: CrumbUser? {
//        users.first
//    }
//
//    var body: some View {
//        ZStack {
//            Color.white.ignoresSafeArea()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Profile Picture and Name
//                    HStack {
//                        if let image = selectedImage {
//                            Image(uiImage: image)
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 80, height: 80)
//                                .clipShape(Circle())
//                                .shadow(radius: 5)
//                        } else {
//                            Image("defaultProfile")
//                                .resizable()
//                                .scaledToFill()
//                                .frame(width: 80, height: 80)
//                                .clipShape(Circle())
//                                .shadow(radius: 5)
//                        }
//
//                        Text(username.isEmpty ? "Username" : username)
//                            .font(.title2)
//                            .bold()
//                            .foregroundColor(Color("Dark Orange"))
//                    }
//
//                    Divider()
//
//                    // Camera to Update Profile Picture
//                    Button(action: {
//                        showCamera = true
//                    }) {
//                        Text("Update Profile Picture")
//                            .foregroundColor(.blue)
//                            .underline()
//                    }
//                    .sheet(isPresented: $showCamera) {
//                        CameraView(selectedImage: $selectedImage) { image in
//                            if let image = image {
//                                saveProfileImage(image)
//                            }
//                        }
//                    }
//
//                    // Form Fields
//                    Group {
//                        formField(title: "Username", text: $username)
//                        formField(title: "Full Name", text: $fullName)
//                        formField(title: "Address", text: $address)
//                        formField(title: "Phone", text: $phoneNumber)
//                        formField(title: "Latitude", text: $latitude)
//                        formField(title: "Longitude", text: $longitude)
//                    }
//
//                    Button(action: saveChanges) {
//                        Text("Save Changes")
//                            .frame(maxWidth: .infinity)
//                            .padding()
//                            .background(Color("Dark Blue"))
//                            .foregroundColor(.white)
//                            .cornerRadius(10)
//                    }
//                }
//                .padding()
//            }
//        }
//        .onAppear {
//            loadUserData()
//        }
//        .navigationTitle("Settings")
//        .navigationBarTitleDisplayMode(.inline)
//    }
//
//    private func formField(title: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(title, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//
//    // MARK: - Load User Data
//    private func loadUserData() {
//        if let user = user {
//            username = user.username ?? ""
//            fullName = user.name ?? ""
//            address = user.address ?? ""
//            phoneNumber = user.phoneNumber ?? ""
//            latitude = String(user.homeLatitude)
//            longitude = String(user.homeLongitude)
//            if let imageData = user.profilePicture, let uiImage = UIImage(data: imageData) {
//                selectedImage = uiImage
//            }
//        }
//    }
//
//    // MARK: - Save Changes
//    private func saveChanges() {
//        let user = self.user ?? CrumbUser(context: viewContext)
//        user.username = username
//        user.name = fullName
//        user.address = address
//        user.phoneNumber = phoneNumber
//        
//        // Validate and save latitude and longitude as strings
//        user.homeLatitude = Double(latitude) ?? 0.0
//        user.homeLongitude = Double(longitude) ?? 0.0
//
//        // Save profile picture if available
//        if let image = selectedImage, let imageData = image.jpegData(compressionQuality: 0.8) {
//            user.profilePicture = imageData
//        }
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save changes: \(error.localizedDescription)")
//        }
//    }
//
//    private func saveProfileImage(_ image: UIImage) {
//        selectedImage = image
//        if let imageData = image.jpegData(compressionQuality: 0.8) {
//            user?.profilePicture = imageData
//            try? viewContext.save()
//        }
//    }
//}
//
//#Preview {
//    EditProfileView()
//}
