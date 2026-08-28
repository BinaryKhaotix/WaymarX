//
//  AddBreadcrumbView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import SwiftUI
import CoreData
import CoreLocation

struct AddBreadcrumbView: View {
    var preselectedGroupName: String? = nil
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var navigationModel: NavigationModel

    // Fetch existing groups for selection
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CrmGroup.groupName, ascending: true)],
        animation: .default
    ) private var groups: FetchedResults<CrmGroup>

    @State private var breadcrumbName: String = ""
    @State private var note: String = ""
    @State private var photoFileName: String = ""
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var selectedImage: UIImage?
    @State private var groupToEdit: CrmGroup? = nil

    // Group selection
    @State private var selectedGroup: CrmGroup? = nil

    // Optional: quick-add a new group name right here
    @State private var isAddingNewGroup: Bool = false
    @State private var newGroupName: String = ""
    
    
    var body: some View {
        VStack {
            // Header
            Text("Capture a moment, add details, and drop your Pin!")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding()

            ScrollView {
                // Image Section
                VStack {
                    Group {
                        if let selectedImage = selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Text("No Image")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, minHeight: 200)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)

                    HStack {
                        Button(action: { showImagePicker = true }) {
                            Text("Select Photo")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(.white))
                                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
                                )
                                .foregroundColor(.blue)
                        }

                        Button(action: { showCamera = true }) {
                            Text("Take Photo")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(Color(.white))
                                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
                                )
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 20)

                VStack(spacing: 20) {
                    // Input Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Pin Name")
                            .font(.headline)
                        TextField("Enter pin name", text: $breadcrumbName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        Text("Group")
                            .font(.headline)

                        // Existing Group Picker
                        Picker("Select group", selection: $selectedGroup) {
                            Text("None").tag(Optional<CrmGroup>.none)
                            ForEach(groups) { group in
                                Text(group.groupName ?? "Unnamed Group")
                                    .tag(Optional(group))
                            }
                        }
                        .pickerStyle(.menu)

                        Button("Edit Selected Group") {
                            if let g = selectedGroup {
                                groupToEdit = g
                            }
                        }
                        .disabled(selectedGroup == nil)
                        .opacity(selectedGroup == nil ? 0.5 : 1.0)

                        // Quick add toggle/button
                        HStack {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isAddingNewGroup.toggle()
                                    if !isAddingNewGroup { newGroupName = "" }
                                }
                            }) {
                                Text(isAddingNewGroup ? "Cancel New Group" : "+ Add New Group")
                                    .font(.subheadline)
                            }

                            Spacer()

                            if selectedGroup != nil {
                                Text("Selected")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }

                        if isAddingNewGroup {
                            TextField("New group name", text: $newGroupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }

                        Text("Note")
                            .font(.headline)
                        TextField("Add a note", text: $note)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding()
                }
            }

            // Save Button
            Button(action: saveBreadcrumb) {
                Text("Save Pin")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color("Dark Orange"))
                    .foregroundColor(.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
            }
            .padding(.horizontal)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Add Pin")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    navigationModel.pop()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                        Text("Back")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage) { _ in
                if let image = selectedImage {
                    photoFileName = saveImageLocally(image) ?? ""
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView(selectedImage: $selectedImage) { image in
                if let image = image {
                    photoFileName = saveImageLocally(image) ?? ""
                }
            }
        }
        .sheet(item: $groupToEdit) { group in
            GroupEditorView(groupToEdit: group)
                .environment(\.managedObjectContext, viewContext)
        }
        .onAppear {
            locationManager.requestLocation()
            

        }
    }

    // MARK: - Save Breadcrumb Logic
    private func saveBreadcrumb() {
        locationManager.requestLocation()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let location = locationManager.currentLocation else {
                print("Failed to get current location.")
                return
            }

            // Initialize breadcrumb
            let breadcrumb = Breadcrumb(context: viewContext)
            breadcrumb.id = UUID()
            breadcrumb.latitude = location.latitude
            breadcrumb.longitude = location.longitude
            breadcrumb.name = breadcrumbName.isEmpty ? "Unnamed Pin" : breadcrumbName
            breadcrumb.dateDropped = Date()
            breadcrumb.note = note
            breadcrumb.photoURL = photoFileName

            // Group assignment logic:
            //
            // 1) If opened from a specific Group, use that Group
            // 2) Else if user selected an existing Group, use it
            // 3) Else if user is creating a new Group, create/find it
            // 4) Else leave the Pin ungrouped

            if let preselectedGroupName = preselectedGroupName {

                let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
                req.fetchLimit = 1
                req.predicate = NSPredicate(
                    format: "groupName ==[c] %@",
                    preselectedGroupName
                )

                do {

                    if let group = try viewContext.fetch(req).first {

                        breadcrumb.crmGroup = group

                        print("Pin assigned to preselected Group: \(group.groupName ?? "Unknown")")

                    } else {

                        print("Could not find preselected Group: \(preselectedGroupName)")

                    }

                } catch {

                    print("Error fetching preselected CrmGroup: \(error.localizedDescription)")

                }

            } else if let selectedGroup = selectedGroup {

                breadcrumb.crmGroup = selectedGroup

            } else {

                let trimmedNewName = newGroupName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

                if isAddingNewGroup, !trimmedNewName.isEmpty {

                    let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
                    req.fetchLimit = 1
                    req.predicate = NSPredicate(
                        format: "groupName ==[c] %@",
                        trimmedNewName
                    )

                    do {

                        if let existing = try viewContext.fetch(req).first {

                            breadcrumb.crmGroup = existing

                        } else {

                            let newGroup = CrmGroup(context: viewContext)

                            newGroup.id = UUID()
                            newGroup.dateCreated = Date()
                            newGroup.groupName = trimmedNewName
                            newGroup.groupDescription = "Created from Pin"

                            breadcrumb.crmGroup = newGroup

                        }

                    } catch {

                        print("Error fetching/creating CrmGroup: \(error.localizedDescription)")

                    }

                }

            }
            // Reverse geocode and save breadcrumb
            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
            locationManager.reverseGeocode(location: clLocation) { placemark in
                DispatchQueue.main.async {
                    breadcrumb.streetAddress = [placemark?.subThoroughfare ?? "", placemark?.thoroughfare ?? ""]
                        .filter { !$0.isEmpty }
                        .joined(separator: " ")
                    breadcrumb.city = placemark?.locality ?? "No City"
                    breadcrumb.state = placemark?.administrativeArea ?? "No State"
                    breadcrumb.zipCode = placemark?.postalCode ?? "No Zip"

                    do {
                        print("Saving Pin: \(breadcrumb.name ?? "Unnamed")")
                        print("Assigned Group: \(breadcrumb.crmGroup?.groupName ?? "NONE")")
                        try viewContext.save()
                        clearFields()
                        print("Pin saved successfully!")
                    } catch {
                        print("Failed to save Pin: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions
    private func clearFields() {
        breadcrumbName = ""
        note = ""
        photoFileName = ""
        selectedImage = nil

        selectedGroup = nil
        isAddingNewGroup = false
        newGroupName = ""
    }

    private func saveImageLocally(_ image: UIImage) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentsURL.appendingPathComponent(fileName)

        do {
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                try imageData.write(to: fileURL)
                return fileName
            }
        } catch {
            print("Failed to save image: \(error.localizedDescription)")
        }
        return nil
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yy'-'h:mm a"
        return formatter.string(from: date)
    }
    
    private func debugPrintGroups() {
        let req: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "groupName", ascending: true)]

        do {
            let all = try viewContext.fetch(req)
            print("Total CrmGroup objects: \(all.count)")

            // Print name + objectID so you can see duplicates are distinct rows
            for g in all {
                let name = g.groupName ?? "nil"
                print("Group:", name, "| objectID:", g.objectID.uriRepresentation().absoluteString)
            }
        } catch {
            print("Fetch error:", error)
        }
    }

}



//import SwiftUI
//import CoreData
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel
//
//    
//    @State private var breadcrumbName: String = ""
//    @State private var selectedGroupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Capture a moment, add details, and drop your Pin!")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                // Image Section
//                VStack {
//                    Group {
//                        if let selectedImage = selectedImage {
//                            Image(uiImage: selectedImage)
//                                .resizable()
//                                .scaledToFit()
//                        } else {
//                            // A placeholder view with a default minimum height
//                            Text("No Image")
//                                .font(.headline)
//                                .foregroundColor(.gray)
//                                .frame(maxWidth: .infinity, minHeight: 200)
//                        }
//                    }
//                    .background(Color.white)
//                    .cornerRadius(30)
//                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                    .padding(.horizontal, 10)
//                    .padding(.bottom, 20)
//
//                    HStack {
//                        Button(action: {
//                            showImagePicker = true
//                        }) {
//                            Text("Select Photo")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(
//                                    RoundedRectangle(cornerRadius: 15)
//                                        .fill(Color(.white))
//                                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                )
//                                .foregroundColor(.blue)
//                        }
//
//                        Button(action: {
//                            showCamera = true
//                        }) {
//                            Text("Take Photo")
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(
//                                    RoundedRectangle(cornerRadius: 15)
//                                        .fill(Color(.white))
//                                        .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                )
//                                .foregroundColor(.blue)
//                        }
//                    }
//                }
//                .padding(.horizontal, 20)
//
//                VStack(spacing: 20) {
//                    // Input Section
//                    VStack(alignment: .leading, spacing: 10) {
//                        Text("Pin Name")
//                            .font(.headline)
//                        TextField("Enter pin name", text: $breadcrumbName)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                        Text("Group")
//                            .font(.headline)
//                        TextField("Enter group name", text: $selectedGroupName)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//
//                        Text("Note")
//                            .font(.headline)
//                        TextField("Add a note", text: $note)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
//                    }
//                    .padding()
//
//                }
//            }
//
//            // Save Button
//            Button(action: saveBreadcrumb) {
//                Text("Save Pin")
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//            }
//            .padding(.horizontal)
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Add Pin")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button {
//                    navigationModel.pop()
//                } label: {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    photoFileName = saveImageLocally(image) ?? ""
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    photoFileName = saveImageLocally(image) ?? ""
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation()
//        }
//    }
//
//    // MARK: - Save Breadcrumb Logic
//    private func saveBreadcrumb() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            // Initialize breadcrumb
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.id = UUID()
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? "Unnamed Pin" : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.photoURL = photoFileName
//
//            // Assign to CrmGroup if a group name is selected
//            if !selectedGroupName.isEmpty {
//                // Define fetch request for CrmGroup
//                let groupFetchRequest: NSFetchRequest<CrmGroup> = CrmGroup.fetchRequest()
//                groupFetchRequest.predicate = NSPredicate(format: "groupName == %@", selectedGroupName)
//
//                do {
//                    let groups = try viewContext.fetch(groupFetchRequest)
//                    if let existingGroup = groups.first {
//                        // Assign existing group to breadcrumb
//                        breadcrumb.crmGroup = existingGroup
//                    } else {
//                        // Create a new CrmGroup and assign it to breadcrumb
//                        let newGroup = CrmGroup(context: viewContext)
//                        newGroup.id = UUID()
//                        newGroup.dateCreated = Date()
//                        newGroup.groupName = selectedGroupName
//                        newGroup.groupDescription = "Created from Pin"
//                        breadcrumb.crmGroup = newGroup
//                    }
//                } catch {
//                    print("Error fetching or creating CrmGroup: \(error.localizedDescription)")
//                }
//            }
//
//            // Reverse geocode and save breadcrumb
//            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
//            locationManager.reverseGeocode(location: clLocation) { placemark in
//                DispatchQueue.main.async {
//                    breadcrumb.streetAddress = [placemark?.subThoroughfare ?? "", placemark?.thoroughfare ?? ""]
//                        .filter { !$0.isEmpty }
//                        .joined(separator: " ")
//                    breadcrumb.city = placemark?.locality ?? "No City"
//                    breadcrumb.state = placemark?.administrativeArea ?? "No State"
//                    breadcrumb.zipCode = placemark?.postalCode ?? "No Zip"
//
//                    do {
//                        // Save breadcrumb to Core Data
//                        try viewContext.save()
//                        clearFields() // Reset input fields after saving
//                        print("Pin saved successfully!")
//                    } catch {
//                        print("Failed to save Pin: \(error.localizedDescription)")
//                    }
//                }
//            }
//        }
//    }
//
//    // MARK: - Helper Functions
//    private func clearFields() {
//        breadcrumbName = ""
//        selectedGroupName = ""
//        note = ""
//        photoFileName = ""
//        selectedImage = nil
//    }
//
//    private func saveImageLocally(_ image: UIImage) -> String? {
//        let fileManager = FileManager.default
//        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
//            return nil
//        }
//        let fileName = UUID().uuidString + ".jpg"
//        let fileURL = documentsURL.appendingPathComponent(fileName)
//
//        do {
//            if let imageData = image.jpegData(compressionQuality: 0.8) {
//                try imageData.write(to: fileURL)
//                return fileName
//            }
//        } catch {
//            print("Failed to save image: \(error.localizedDescription)")
//        }
//        return nil
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "MM/dd/yy'-'h:mm a"
//        return formatter.string(from: date)
//    }
//}

//import SwiftUI
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared instance of LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Capture a moment, add details, and drop your breadcrumb!")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Input Section
//                    AddBreadcrumbInputSection(
//                        breadcrumbName: $breadcrumbName,
//                        crmGroup?.groupName: $crmGroup?.groupName,
//                        note: $note
//                    )
//
//                    // Image Section
//                    AddBreadcrumbImageSection(
//                        selectedImage: $selectedImage,
//                        showCamera: $showCamera,
//                        showImagePicker: $showImagePicker
//                    )
//
//                    // Location Display Section
//                    AddBreadcrumbLocationSection(locationManager: locationManager)
//                }
//                .padding(.horizontal)
//            }
//
//            // Save Button
//            Button(action: saveBreadcrumb) {
//                Text("Save Crumb")
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//                    .padding(.horizontal)
//            }
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Add Crumb")
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
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation()
//        }
//    }
//
//    // MARK: - Save Breadcrumb Logic
//    private func saveBreadcrumb() {
//        locationManager.requestLocation() // Request current location
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Allow time for location updates
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.id = UUID()
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//            breadcrumb.photoURL = photoFileName
//
//            // Fetch address and save to Core Data
//            let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
//            locationManager.reverseGeocode(location: clLocation) { placemark in
//                DispatchQueue.main.async {
//                    breadcrumb.streetAddress = placemark?.subThoroughfare ?? "No Address"
//                    breadcrumb.city = placemark?.locality ?? "No City"
//                    breadcrumb.state = placemark?.administrativeArea ?? "No State"
//                    breadcrumb.zipCode = placemark?.postalCode ?? "No Zip"
//                    do {
//                        try viewContext.save()
//                        clearFields()
//                    } catch {
//                        print("Failed to save breadcrumb: \(error.localizedDescription)")
//                    }
//                }
//            }
//        }
//    }

    
    //    private func saveBreadcrumb() {
//        locationManager.requestLocation() // Ensure the latest location is fetched
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//            breadcrumb.photoURL = photoFileName
//
//            // Perform reverse geocoding to get address details
//            let locationObject = CLLocation(latitude: location.latitude, longitude: location.longitude)
//            locationManager.reverseGeocode(location: locationObject) { placemark in
//                if let placemark = placemark {
//                    breadcrumb.streetAddress = [
//                        placemark.subThoroughfare ?? "",
//                        placemark.thoroughfare ?? ""
//                    ]
//                    .filter { !$0.isEmpty }
//                    .joined(separator: " ")
//
//                    breadcrumb.city = placemark.locality ?? "No City"
//                    breadcrumb.state = placemark.administrativeArea ?? "No State"
//                    breadcrumb.zipCode = placemark.postalCode ?? "No Zip"
//
//                    // Save the breadcrumb with address details
//                    do {
//                        try viewContext.save()
//                        clearFields()
//                        print("Breadcrumb saved successfully with address details.")
//                    } catch {
//                        print("Failed to save breadcrumb: \(error.localizedDescription)")
//                    }
//                } else {
//                    print("Failed to fetch address details. Saving breadcrumb without address.")
//                    // Save the breadcrumb even if address details are unavailable
//                    do {
//                        try viewContext.save()
//                        clearFields()
//                    } catch {
//                        print("Failed to save breadcrumb: \(error.localizedDescription)")
//                    }
//                }
//            }
//        }
//    }

//    private func saveBreadcrumb() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//            breadcrumb.photoURL = photoFileName
//
//            do {
//                try viewContext.save()
//                clearFields()
//            } catch {
//                print("Failed to save breadcrumb: \(error.localizedDescription)")
//            }
//        }
//    }

//    private func clearFields() {
//        breadcrumbName = ""
//        // crmGroup?.groupName = ""
//        note = ""
//        photoFileName = ""
//        selectedImage = nil
//    }
//
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}
//
//// MARK: - Subviews
//struct AddBreadcrumbInputSection: View {
//    @Binding var breadcrumbName: String
//    @Binding var crmGroup?.groupName: String
//    @Binding var note: String
//
//    var body: some View {
//        Section {
//            Group {
//                inputField(title: "Crumb Name", placeholder: "Enter name", text: $breadcrumbName)
//                inputField(title: "Group Name", placeholder: "Enter group", text: $crmGroup?.groupName)
//                inputField(title: "Note", placeholder: "Add a note", text: $note)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//
//    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange")) // Title color
//
//            TextField("", text: text)
//                .placeholder(placeholder, when: text.wrappedValue.isEmpty) // Darker placeholder
//                .padding(5)
//                .background(Color.white) // Ensure white background
//                .cornerRadius(8)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 8)
//                        .stroke(Color.gray.opacity(0.5), lineWidth: 1) // Optional border
//                )
//                .foregroundColor(.black) // Input text color
//        }
//    }
//}
//
//struct AddBreadcrumbImageSection: View {
//    @Binding var selectedImage: UIImage?
//    @Binding var showCamera: Bool
//    @Binding var showImagePicker: Bool
//
//    var body: some View {
//        Section {
//            ZStack {
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(maxWidth: .infinity)
//                        .cornerRadius(15)
//                        .shadow(radius: 5)
//                        .padding(.bottom, 10)
//                } else {
//                    Rectangle()
//                        .fill(Color.gray.opacity(0.2))
//                        .frame(maxWidth: .infinity, maxHeight: 300)
//                        .frame(height: 100)
//                        .overlay(
//                            Text("No Image Available")
//                                .font(.headline)
//                                .foregroundColor(.gray)
//                        )
//                        .cornerRadius(15)
//                        //.shadow(color: .black.opacity(0.8), radius: 1, x: 1, y: 1)
//                        .padding(.horizontal, 20)
//                }
//            }
//
//            HStack(spacing: 40) {
//                Button(action: { showCamera = true }) {
//                    Image(systemName: "camera")
//                        .font(.largeTitle)
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding()
//                        .background(Color.white)
//                        .clipShape(Circle())
//                        .shadow(radius: 5)
//                }
//                Divider()
//                Button(action: { showImagePicker = true }) {
//                    Image(systemName: "photo.on.rectangle")
//                        .font(.largeTitle)
//                        .foregroundColor(Color("Dark Blue"))
//                        .padding()
//                        .background(Color.white)
//                        .clipShape(Circle())
//                        .shadow(radius: 5)
//                }
//            }
//            .frame(maxWidth: .infinity)
//            .padding()
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//}
//
//struct AddBreadcrumbLocationSection: View {
//    @ObservedObject var locationManager: LocationManager
//
//    var body: some View {
//        Section {
//            VStack(alignment: .leading, spacing: 10) {
//                Text("Location")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//
//                // Geo Location
//                if let currentLocation = locationManager.currentLocation {
//                    let formattedLatitude = String(format: "%.6f", currentLocation.latitude)
//                    let formattedLongitude = String(format: "%.6f", currentLocation.longitude)
//
//                    locationText(
//                        title: "Geo Location",
//                        value: "\(formattedLatitude), \(formattedLongitude)"
//                    )
//                    .foregroundColor(.black)
//                } else {
//                    locationText(title: "Geo Location", value: "Fetching location...")
//                        .foregroundColor(.black)
//                }
//
//                // Address
//                locationText(
//                    title: "Address",
//                    value: formattedAddress
//                )
//                .foregroundColor(.black)
//            }
//        }
//        .padding()
//        .background(Color.white)
//        .cornerRadius(15)
//        .shadow(radius: 5)
//    }
//
//    // Computed property for the formatted address
//    private var formattedAddress: String {
//        let address = "\(locationManager.streetAddress), \(locationManager.city), \(locationManager.state) \(locationManager.zipCode)"
//        print("Debug Address: \(address)") // Debug print here
//        return address
//    }
//
//    private func locationText(title: String, value: String) -> some View {
//        HStack {
//            Text("\(title):")
//                .font(.subheadline)
//                .bold()
//            Text(value)
//                .font(.subheadline)
//        }
//    }
//}
//
//extension View {
//    func placeholder<Content: View>(
//        _ text: String,
//        when shouldShow: Bool,
//        alignment: Alignment = .leading,
//        @ViewBuilder placeholder: () -> Content
//    ) -> some View {
//        ZStack(alignment: alignment) {
//            if shouldShow {
//                placeholder()
//            }
//            self
//        }
//    }
//
//    func placeholder(_ text: String, when shouldShow: Bool) -> some View {
//        placeholder(text, when: shouldShow, alignment: .leading) {
//            Text(text)
//                .foregroundColor(Color(.black).opacity(0.4))
//                .padding(10)
//        }
//    }
//}



//import SwiftUI
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared instance of LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        VStack {
//            // Header
//            Text("Capture a moment, add details, and drop your breadcrumb!")
//                .font(.subheadline)
//                .foregroundColor(.gray)
//                .multilineTextAlignment(.center)
//                .padding()
//
//            ScrollView {
//                VStack(spacing: 20) {
//                    // Input Section
//                    Section {
//                        Group {
//                            inputField(title: "Crumb Name", placeholder: "Enter name", text: $breadcrumbName)
//                            inputField(title: "Group Name", placeholder: "Enter group", text: $crmGroup?.groupName)
//                            inputField(title: "Note", placeholder: "Add a note", text: $note)
//                        }
//                    }
//                    .padding()
//                    .background(Color.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//
//                    // Image Section
//                    Section {                        
//                        ZStack {
//                            if let image = selectedImage {
//                                Image(uiImage: image)
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(maxWidth: .infinity)
//                                    .cornerRadius(15)
//                                    .shadow(radius: 5)
//                                    .padding(.bottom, 10)
//                            } else {
//                                Rectangle()
//                                    .fill(Color.gray.opacity(0.2))
//                                    .frame(maxWidth: .infinity, height: 300)
//                                    .overlay(
//                                        Text("No Image Available")
//                                            .font(.headline)
//                                            .foregroundColor(.gray)
//                                    )
//                                    .cornerRadius(15)
//                                    .shadow(color: .black.opacity(0.8), radius: 5, x: 5, y: 5)
//                                    .padding(.horizontal, 20)
//                            }
//                        }
//
//                        HStack(spacing: 40) {
//                            Button(action: { showCamera = true }) {
//                                Image(systemName: "camera")
//                                    .font(.largeTitle)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding()
//                                    .background(Color.white)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            }
//                            
//                            Button(action: { showImagePicker = true }) {
//                                Image(systemName: "photo.on.rectangle")
//                                    .font(.largeTitle)
//                                    .foregroundColor(Color("Dark Blue"))
//                                    .padding()
//                                    .background(Color.white)
//                                    .clipShape(Circle())
//                                    .shadow(radius: 5)
//                            }
//                        }
//                        .frame(maxWidth: .infinity) // Match the section width
//                        .padding()
//                    }
//                    .padding()
//                    .background(Color.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//
//                    // Location Display
//                    Section {
//                        VStack(alignment: .leading, spacing: 10) {
//                            Text("Location")
//                                .font(.headline)
//                                .foregroundColor(Color("Dark Blue"))
//
//                            if let currentLocation = locationManager.currentLocation {
//                                locationText(
//                                    title: "Geo Location",
//                                    value: "\(currentLocation.latitude), \(currentLocation.longitude)"
//                                )
//                            } else {
//                                locationText(title: "Geo Location", value: "Fetching location...")
//                                    .foregroundColor(.gray)
//                            }
//
//                            locationText(title: "City", value: locationManager.city)
//                            locationText(title: "State", value: locationManager.state)
//                            locationText(title: "Zip Code", value: locationManager.zipCode)
//                        }
//                    }
//                    .padding()
//                    .background(Color.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//                }
//                .padding(.horizontal)
//            }
//
//            // Save Button
//            Button(action: saveBreadcrumb) {
//                Text("Save Crumb")
//                    .font(.headline)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(.white)
//                    .cornerRadius(15)
//                    .shadow(radius: 5)
//                    .padding(.horizontal)
//            }
//        }
//        .background(Color(.systemGroupedBackground).ignoresSafeArea())
//        .navigationTitle("Add Crumb")
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
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation()
//        }
//    }
//
//    // MARK: - Helper Views
//    private func inputField(title: String, placeholder: String, text: Binding<String>) -> some View {
//        VStack(alignment: .leading, spacing: 5) {
//            Text(title)
//                .font(.headline)
//                .foregroundColor(Color("Dark Orange"))
//            TextField(placeholder, text: text)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//        }
//    }
//
//    private func labelWithIcon(icon: String, text: String) -> some View {
//        HStack {
//            Image(systemName: icon)
//            Text(text)
//        }
//        .font(.headline)
//        .padding()
//        .background(Color("Dark Blue"))
//        .foregroundColor(.white)
//        .cornerRadius(10)
//    }
//
//    private func locationText(title: String, value: String) -> some View {
//        HStack {
//            Text("\(title):")
//                .font(.subheadline)
//                .bold()
//            Text(value)
//                .font(.subheadline)
//        }
//    }
//
//    // MARK: - Save Breadcrumb Logic
//    private func saveBreadcrumb() {
//        locationManager.requestLocation()
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//            breadcrumb.photoURL = photoFileName
//
//            do {
//                try viewContext.save()
//                clearFields()
//            } catch {
//                print("Failed to save breadcrumb: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    private func clearFields() {
//        breadcrumbName = ""
//        crmGroup?.groupName = ""
//        note = ""
//        photoFileName = ""
//        selectedImage = nil
//    }
//
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared instance of LocationManager
//    @EnvironmentObject var navigationModel: NavigationModel // Use navigation model
//
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
////                Text("Add a New Breadcrumb")
////                    .font(.title)
////                    .bold()
////                    .foregroundColor(Color("Dark Blue"))
//
//                // Breadcrumb Name
//                TextField("Breadcrumb Name", text: $breadcrumbName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Group Name
//                TextField("Group Name", text: $crmGroup?.groupName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Note
//                TextField("Note", text: $note)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Photo Options
//                HStack(spacing: 20) {
//                    Button(action: { showCamera = true }) {
//                        Text("Take Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                    Button(action: { showImagePicker = true }) {
//                        Text("Select Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                }
//                .padding(.top, 10)
//
//                // Show Selected Image
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Location Display
//                if let currentLocation = locationManager.currentLocation {
//                    HStack {
//                        Text("Geo Location: ")
//                        Text("\(currentLocation.latitude), \(currentLocation.longitude)")
//                            .foregroundColor(.blue)
//                    }
//                } else {
//                    Text("Fetching Location...")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//
//                // Address Information
//                HStack {
//                    Text("Real Location: ")
//                    Text("\(locationManager.city)")
//                        .foregroundColor(.blue)
//                    Text("\(locationManager.state)")
//                        .foregroundColor(.blue)
//                    Text(" \(locationManager.zipCode)")
//                        .foregroundColor(.blue)
//                }
//
//                // Save Button
//                Button(action: saveBreadcrumb) {
//                    Text("Save Breadcrumb")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//            }
//            .padding()
//        }
//        .background(Color(.white).ignoresSafeArea())
//        .navigationTitle("Add Crumb")
//        .navigationBarTitleDisplayMode(.inline)
//        .navigationBarBackButtonHidden(true)
//        .toolbar {
//            ToolbarItem(placement: .navigationBarLeading) {
//                Button(action: {
//                    // Navigate back dynamically
//                    navigationModel.path.removeLast()
//                }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                            .foregroundColor(.white)
//                        Text("Back")
//                            .foregroundColor(.white)
//                    }
//                }
//            }
//        }
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation() // Request location when the view appears
//        }
//    }
//
//    // MARK: - Save Image Locally
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    // MARK: - Save Breadcrumb
//    private func saveBreadcrumb() {
//        locationManager.requestLocation() // Ensure we get the latest location
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { // Allow time for location to update
//            guard let location = locationManager.currentLocation else {
//                print("Failed to get current location.")
//                return
//            }
//
//            let breadcrumb = Breadcrumb(context: viewContext)
//            breadcrumb.latitude = location.latitude
//            breadcrumb.longitude = location.longitude
//            breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//            breadcrumb.dateDropped = Date()
//            breadcrumb.note = note
//            breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//            breadcrumb.photoURL = photoFileName
//
//            do {
//                try viewContext.save()
//                clearFields() // Clear form fields after saving
//            } catch {
//                print("Failed to save breadcrumb: \(error.localizedDescription)")
//            }
//        }
//    }
//
//    // MARK: - Clear Fields
//    private func clearFields() {
//        breadcrumbName = ""
//        //crmGroup?.groupName = ""
//        note = ""
//        photoFileName = ""
//        selectedImage = nil
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager // Shared instance of LocationManager
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                Text("Add a New Breadcrumb")
//                    .font(.title)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue"))
//
//                // Breadcrumb Name
//                TextField("Breadcrumb Name", text: $breadcrumbName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Group Name
//                TextField("Group Name", text: $crmGroup?.groupName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Note
//                TextField("Note", text: $note)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Photo Options
//                HStack(spacing: 20) {
//                    Button(action: { showCamera = true }) {
//                        Text("Take Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                    Button(action: { showImagePicker = true }) {
//                        Text("Select Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                }
//                .padding(.top, 10)
//
//                // Show Selected Image
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Location Display
//                if let currentLocation = locationManager.currentLocation {
//                    HStack {
//                        Text("Geo Location: ")
//                        Text("\(currentLocation.latitude), \(currentLocation.longitude)")
//                            .foregroundColor(.blue)
//                    }
//                } else {
//                    Text("Fetching Location...")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//
//                // Address Information
//                HStack {
//                    Text("Real Location: ")
//                    Text("\(locationManager.city)")
//                        .foregroundColor(.blue)
//                    Text("\(locationManager.state)")
//                        .foregroundColor(.blue)
//                    Text(" \(locationManager.zipCode)")
//                        .foregroundColor(.blue)
//                }
//                //.padding()
//
//                // Save Button
//                Button(action: saveBreadcrumb) {
//                    Text("Save Breadcrumb")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//            }
//            .padding()
//        }
//        .background(Color(.white).ignoresSafeArea())
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation() // Request location when the view appears
//        }
//    }
//
//    // MARK: - Save Image Locally
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    // MARK: - Save Breadcrumb
//    private func saveBreadcrumb() {
//        guard let location = locationManager.currentLocation else { return }
//
//        let breadcrumb = Breadcrumb(context: viewContext)
//        breadcrumb.latitude = location.latitude
//        breadcrumb.longitude = location.longitude
//        breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//        breadcrumb.dateDropped = Date()
//        breadcrumb.note = note
//        breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//        breadcrumb.photoURL = photoFileName
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save breadcrumb: \(error.localizedDescription)")
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//}


//import SwiftUI
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @StateObject var locationManager = LocationManager()
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                Text("Add a New Breadcrumb")
//                    .font(.title)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue"))
//
//                TextField("Breadcrumb Name", text: $breadcrumbName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                TextField("Group Name", text: $crmGroup?.groupName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                TextField("Note", text: $note)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                HStack(spacing: 20) {
//                    Button(action: { showCamera = true }) {
//                        Text("Take Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                    Button(action: { showImagePicker = true }) {
//                        Text("Select Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                }
//                .padding(.top, 10)
//
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                if let location = locationManager.currentLocation {
//                    Text("Latitude: \(location.latitude)")
//                    Text("Longitude: \(location.longitude)")
//                } else {
//                    Text("Fetching Location...")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//
//                Button(action: saveBreadcrumb) {
//                    Text("Save Breadcrumb")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//            }
//            .padding()
//        }
//        .background(Color(.white).ignoresSafeArea())
//        .onAppear {
//            locationManager.requestLocation()
//        }
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//    }
//
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    private func saveBreadcrumb() {
//        guard let location = locationManager.currentLocation else { return }
//
//        let breadcrumb = Breadcrumb(context: viewContext)
//        breadcrumb.latitude = location.latitude
//        breadcrumb.longitude = location.longitude
//        breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//        breadcrumb.dateDropped = Date()
//        breadcrumb.note = note
//        breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//        breadcrumb.photoURL = photoFileName
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save breadcrumb: \(error.localizedDescription)")
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//}


//import SwiftUI
//import CoreData
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @ObservedObject var locationManager: LocationManager
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//    @State private var currentLocation: CLLocationCoordinate2D?
//
//    //var initialLocation: CLLocationCoordinate2D? // Pass location from parent view if available
//
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                Text("Add a New Breadcrumb")
//                    .font(.title)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue")) // Dynamic text color
//
//                // Breadcrumb Name
//                TextField("Breadcrumb Name", text: $breadcrumbName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Group Name
//                TextField("Group Name", text: $crmGroup?.groupName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Note
//                TextField("Note", text: $note)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Photo Options
//                HStack(spacing: 20) {
//                    Button(action: { showCamera = true }) {
//                        Text("Take Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                    Button(action: { showImagePicker = true }) {
//                        Text("Select Photo")
//                            .foregroundColor(Color("Dark Blue"))
//                            .underline()
//                    }
//                }
//                .padding(.top, 10)
//
//                // Show Selected Image
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Coordinates Display
//                if let location = currentLocation {
//                    Text("Latitude: \(location.latitude)")
//                    Text("Longitude: \(location.longitude)")
//                } else {
//                    Text("Fetching Location...")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//
//                // Save Button
//                Button(action: saveBreadcrumb) {
//                    Text("Save Breadcrumb")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//            }
//            .padding()
//        }
//        .background(Color(.white).ignoresSafeArea()) // Dynamic background color
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation()
//            currentLocation = locationManager.currentLocation
//        }
//    }
//
//    // MARK: - Helper Functions
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    private func saveBreadcrumb() {
//        guard let location = currentLocation else { return }
//
//        let breadcrumb = Breadcrumb(context: viewContext)
//        breadcrumb.latitude = location.latitude
//        breadcrumb.longitude = location.longitude
//        breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//        breadcrumb.dateDropped = Date()
//        breadcrumb.note = note
//        breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//        breadcrumb.photoURL = photoFileName
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save breadcrumb: \(error.localizedDescription)")
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//}



//import SwiftUI
//import CoreData
//import CoreLocation
//
//struct AddBreadcrumbView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @ObservedObject var locationManager: LocationManager
//
//    @State private var breadcrumbName: String = ""
//    @State private var crmGroup?.groupName: String = ""
//    @State private var note: String = ""
//    @State private var photoFileName: String = ""
//    @State private var showImagePicker = false
//    @State private var showCamera = false
//    @State private var selectedImage: UIImage?
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 20) {
//                Text("Add a New Breadcrumb")
//                    .font(.title)
//                    .bold()
//                    .foregroundColor(Color("Dark Blue")) // Dynamic text color
//
//                // Breadcrumb Name
//                TextField("Breadcrumb Name", text: $breadcrumbName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Group Name
//                TextField("Group Name", text: $crmGroup?.groupName)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Note
//                TextField("Note", text: $note)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .padding(.horizontal)
//
//                // Photo Options
//                HStack(spacing: 20) {
//                    Button("Take Photo") {
//                        showCamera = true
//                    }
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(Color("Dark Blue"))
//                    .cornerRadius(10)
//
//                    Button("Select Photo") {
//                        showImagePicker = true
//                    }
//                    .padding()
//                    .background(Color("Dark Orange"))
//                    .foregroundColor(Color("Dark Blue"))
//                    .cornerRadius(10)
//                }
//
//                // Show Selected Image
//                if let image = selectedImage {
//                    Image(uiImage: image)
//                        .resizable()
//                        .scaledToFit()
//                        .frame(height: 200)
//                        .cornerRadius(10)
//                        .padding()
//                }
//
//                // Coordinates Display
//                if let location = locationManager.currentLocation {
//                    Text("Latitude: \(location.latitude)")
//                    Text("Longitude: \(location.longitude)")
//                } else {
//                    Text("Fetching Location...")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//
//                // Save Button
//                Button(action: saveBreadcrumb) {
//                    Text("Save Breadcrumb")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//            }
//            .padding()
//        }
//        .background(Color(.white).ignoresSafeArea()) // Dynamic background color
//        .sheet(isPresented: $showImagePicker) {
//            ImagePicker(selectedImage: $selectedImage) { _ in
//                if let image = selectedImage {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .sheet(isPresented: $showCamera) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    saveImageLocally(image)
//                }
//            }
//        }
//        .onAppear {
//            locationManager.requestLocation()
//        }
//    }
//
//
//    // MARK: - Helper Functions
//    private func saveImageLocally(_ image: UIImage) {
//        let fileName = UUID().uuidString + ".jpg"
//        if let data = image.jpegData(compressionQuality: 0.8) {
//            let url = getDocumentsDirectory().appendingPathComponent(fileName)
//            try? data.write(to: url)
//            photoFileName = fileName
//        }
//    }
//
//    private func getDocumentsDirectory() -> URL {
//        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
//    }
//
//    private func saveBreadcrumb() {
//        guard let location = locationManager.currentLocation else { return }
//
//        let breadcrumb = Breadcrumb(context: viewContext)
//        breadcrumb.latitude = location.latitude
//        breadcrumb.longitude = location.longitude
//        breadcrumb.name = breadcrumbName.isEmpty ? formattedDate(Date()) : breadcrumbName
//        breadcrumb.dateDropped = Date()
//        breadcrumb.note = note
//        breadcrumb.crmGroup?.groupName = crmGroup?.groupName
//        breadcrumb.photoURL = photoFileName
//
//        do {
//            try viewContext.save()
//        } catch {
//            print("Failed to save breadcrumb: \(error.localizedDescription)")
//        }
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
//        return formatter.string(from: date)
//    }
//}
