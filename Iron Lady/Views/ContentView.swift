//
//  ContentView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import CoreData
import CoreLocation
import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var locationManager: LocationManager

    @State private var selectedImage: UIImage?
    @State private var lastDroppedCrumbDate: String = "No Pin Dropped Yet"
    @State private var showPopup = false
    @State private var showAddBreadcrumbView = false
    @State private var showCameraView = false
    @State private var countdown: Int = 5
    @State private var isUpdatingRecords: Bool = false
    @State private var updateProgress: Double = 0.0
    @State private var currentBreadcrumb: Breadcrumb? = nil

    // MARK: - UI Constants
    private let maxContentWidth: CGFloat = 520
    private let primaryCorner: CGFloat = 28

    var body: some View {
        ZStack {
            // Background (subtle, modern)
            LinearGradient(
                colors: [
                    Color.white,
                    Color.white.opacity(0.95),
                    Color.white
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer(minLength: 14)

                header

                lastPinCard

                primaryActionButton

                secondaryActions

                Spacer(minLength: 10)

                footer
                    .padding(.bottom, 10)

                if showPopup {
                    popupView
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .frame(maxWidth: maxContentWidth)
            .padding(.horizontal, 20)

            if isUpdatingRecords {
                updatingOverlay
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            fetchLastDroppedCrumb()
        }
        .sheet(isPresented: $showAddBreadcrumbView) {
            AddBreadcrumbView()
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showCameraView) {
            CameraView(selectedImage: $selectedImage) { image in
                if let image = image {
                    attachPhotoToCurrentBreadcrumb(image)
                }
                showCameraView = false
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 10) {
            Image("WaymarX Title Text")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 420)
                .accessibilityHidden(true)

            // Optional: a tiny subtitle (comment out if you hate it)
            // Text("Drop pins. Remember places. Pretend your memory is perfect.")
            //     .font(.subheadline)
            //     .foregroundStyle(.secondary)
        }
    }

    private var lastPinCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Last Pin")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(lastDroppedCrumbDate)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color("Dark Blue"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private var primaryActionButton: some View {
        Button {
            // Haptic to make it feel “real”
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()

            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                dropQuickCrumb()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color("Dark Blue").opacity(0.10))
                        .frame(width: 56, height: 56)

                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color("Dark Blue"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Mark the Spot")
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color("Dark Blue"))

                    Text("Drop a pin at your current location")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color("Dark Blue").opacity(0.7))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: primaryCorner, style: .continuous)
                    .fill(Color("Dark Orange"))
            )
            .overlay(
                RoundedRectangle(cornerRadius: primaryCorner, style: .continuous)
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var secondaryActions: some View {
        VStack(spacing: 12) {
            Button {
                navigationModel.path.append(.dashboard)
            } label: {
                HStack {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16, weight: .semibold))

                    Text("Dashboard")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundStyle(Color("Dark Blue"))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.black.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Text("© 2025 Binary Khaotix · Freedom Automation, Inc.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
    }

    private var updatingOverlay: some View {
        VStack(spacing: 12) {
            Text("Updating Records")
                .font(.headline)
                .foregroundStyle(.white)

            ProgressView(value: updateProgress, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: Color("Dark Orange")))
                .padding(.horizontal, 30)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.55).ignoresSafeArea())
        .transition(.opacity)
    }
    
    // MARK: - Popup View
    private var popupView: some View {
        VStack(spacing: 20) {
            Text("What would you like to do?")
                .font(.headline)
                .foregroundColor(Color("Dark Blue"))

            HStack {
                Button("Take Photo") {
                    showCameraView = true
                    showPopup = false
                }
                .padding()
                .background(Color("Dark Orange"))
                .foregroundColor(Color("Dark Blue"))
                .cornerRadius(10)

                Button("Add Info") {
                    showAddBreadcrumbView = true
                    showPopup = false
                }
                .padding()
                .background(Color("Dark Orange"))
                .foregroundColor(Color("Dark Blue"))
                .cornerRadius(10)
            }

            Button("Cancel") {
                showPopup = false
            }
            .padding(.top, 10)

            Text("Closing in \(countdown)...")
                .font(.footnote)
                .foregroundColor(.red)
        }
        .frame(width: 300)
        .padding()
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }

    // MARK: - Drop Crumb (Only once)
    private func dropQuickCrumb() {
        locationManager.requestLocation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let location = locationManager.currentLocation else {
                print("Location not ready.")
                return
            }

            let breadcrumb = Breadcrumb(context: viewContext)
            breadcrumb.id = UUID()
            breadcrumb.dateDropped = Date()
            breadcrumb.latitude = location.latitude
            breadcrumb.longitude = location.longitude
            breadcrumb.name = "Unnamed Pin"
            currentBreadcrumb = breadcrumb

            let locationObject = CLLocation(latitude: location.latitude, longitude: location.longitude)
            locationManager.reverseGeocode(location: locationObject) { placemark in
                breadcrumb.streetAddress = [placemark?.subThoroughfare ?? "", placemark?.thoroughfare ?? ""]
                    .filter { !$0.isEmpty }
                    .joined(separator: ",")
                breadcrumb.city = placemark?.locality ?? "No City"
                breadcrumb.state = placemark?.administrativeArea ?? "No State"
                breadcrumb.zipCode = placemark?.postalCode ?? "No Zip"

                do {
                    try viewContext.save()
                    lastDroppedCrumbDate = formattedDate(breadcrumb.dateDropped)
                } catch {
                    print("Failed to save Pin: \(error.localizedDescription)")
                }
            }

            showPopup = true
            countdown = 5
            startCountdown()
        }
    }

    // MARK: - Attach Photo to Existing Crumb
    private func attachPhotoToCurrentBreadcrumb(_ image: UIImage) {
        guard let breadcrumb = currentBreadcrumb else { return }

        if let savedPath = saveImageToDocuments(image: image) {
            breadcrumb.photoURL = savedPath

            do {
                try viewContext.save()
                print("Photo added to existing Pin.")
            } catch {
                print("Failed to update Pin with photo: \(error.localizedDescription)")
            }
        }
    }

    private func fetchLastDroppedCrumb() {
        let fetchRequest: NSFetchRequest<Breadcrumb> = Breadcrumb.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Breadcrumb.dateDropped, ascending: false)]
        fetchRequest.fetchLimit = 1

        do {
            if let lastCrumb = try viewContext.fetch(fetchRequest).first {
                lastDroppedCrumbDate = formattedDate(lastCrumb.dateDropped)
            }
        } catch {
            lastDroppedCrumbDate = "No Pin Dropped Yet"
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                showPopup = false
            }
        }
    }

    private func saveImageToDocuments(image: UIImage) -> String? {
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }

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

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd, yyyy 'at' h:mm a"
        return formatter.string(from: date)
    }
}

//Replaced on 01162026 - FOR MODERNIZATION
//import SwiftUI
//import CoreData
//import CoreLocation
//
//struct ContentView: View {
//    @EnvironmentObject var navigationModel: NavigationModel
//    @Environment(\.managedObjectContext) private var viewContext
//    @EnvironmentObject var locationManager: LocationManager
//
//    @State private var selectedImage: UIImage?
//    @State private var lastDroppedCrumbDate: String = "No Pin Dropped Yet"
//    @State private var showPopup = false
//    @State private var showAddBreadcrumbView = false
//    @State private var showCameraView = false
//    @State private var countdown: Int = 5
//    @State private var isUpdatingRecords: Bool = false
//    @State private var updateProgress: Double = 0.0
//    @State private var currentBreadcrumb: Breadcrumb? = nil
//
//    var body: some View {
//        ZStack {
//            Color.white //("Dark Blue")
//                .edgesIgnoringSafeArea(.all)
////            Image("SplashBackround")
////                .resizable()
////                .scaledToFill()
////                .edgesIgnoringSafeArea(.all)
//
//            VStack(spacing: 20) {
//                Spacer()
//                Image("WaymarX Title Text")
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 400, height: 200)
//
//                HStack {
//                    Text("Last Pin: ")
//                        .font(.custom("Marker Felt", size: 18))
//                        .foregroundColor(Color("Light Blue"))
//                    Text(lastDroppedCrumbDate)
//                        .font(.custom("Marker Felt", size: 18))
//                        .foregroundColor(Color("Light Blue"))
//                        .italic()
//                }
//
//                Button(action: {
//                    dropQuickCrumb()
//                }) {
//                    VStack {
//                        Image(systemName: "mappin.and.ellipse")
//                            .resizable()
//                            .scaledToFit()
//                            .frame(width: 100, height: 100)
//                            .tint(Color("Dark Blue"))
//                        Text("Mark the Spot")
//                            .font(.custom("Marker Felt", size: 30))
//                            .bold()
//                            .foregroundColor(Color("Dark Blue"))
//                    }
//                    .frame(width: 300, height: 300)
//                    .background(Color("Dark Orange"))
//                    .cornerRadius(75)
//                    .shadow(color: Color.white.opacity(0.4), radius: 5, x: 5, y: 5)
//                }
//                Spacer()
//                Button(action: {
//                    navigationModel.path.append(.dashboard)
//                }) {
//                    Text("Dashboard")
//                        .font(.custom("Marker Felt", size: 24))
//                        .frame(maxWidth: 300, maxHeight: 50)
//                        .background(Color("Dark Orange"))
//                        .foregroundColor(Color("Dark Blue"))
//                        .bold()
//                        .cornerRadius(25)
//                        .shadow(color: Color.white.opacity(0.4), radius: 5, x: 5, y: 5)
//
//                }
//                Spacer()
//                Text("(c) 2025 - Binary Khaotix, Freedom Automation, Inc.")
//                    .font(.custom("Marker Felt", size: 16))
//                    .foregroundColor(Color("Light Blue"))
//
//
//                if showPopup {
//                    popupView
//                }
//            }
//
//            if isUpdatingRecords {
//                VStack {
//                    Text("Updating Records")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .padding(.bottom, 10)
//                    ProgressView(value: updateProgress, total: 1.0)
//                        .progressViewStyle(LinearProgressViewStyle(tint: Color("Dark Orange")))
//                        .padding(.horizontal, 40)
//                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .background(Color.black.opacity(0.6).ignoresSafeArea())
//            }
//        }
//        .navigationBarBackButtonHidden()
//        .onAppear {
//            performUpdates()
//            fetchLastDroppedCrumb()
//        }
//        .sheet(isPresented: $showAddBreadcrumbView) {
//            AddBreadcrumbView()
//                .environment(\.managedObjectContext, viewContext)
//        }
//        .sheet(isPresented: $showCameraView) {
//            CameraView(selectedImage: $selectedImage) { image in
//                if let image = image {
//                    attachPhotoToCurrentBreadcrumb(image)
//                }
//                showCameraView = false
//            }
//        }
//    }
