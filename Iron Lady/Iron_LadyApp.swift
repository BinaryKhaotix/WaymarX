//
//  Iron_LadyApp.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import SwiftUI
import UIKit

@main
struct IronLadyApp: App {

    let persistenceController = PersistenceController.shared

    @StateObject private var navigationModel = NavigationModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var breadcrumbStore = BreadcrumbStore()

    @StateObject private var arrivalManager =
        WantToGoArrivalManager.shared

    @StateObject private var tipManager =
        ContextualTipManager.shared

    @StateObject private var diagnosticsStore =
        DiagnosticsStore.shared

    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = true

    @AppStorage("appColorScheme")
    private var appColorScheme: String = "system"

    private var preferredScheme: ColorScheme? {
        switch appColorScheme {
        case "light":
            return .light

        case "dark":
            return .dark

        default:
            return nil
        }
    }

    
    init() {

        WantToGoArrivalManager.shared.start()

        configureNavigationBarAppearance()
    }

    var body: some Scene {

        WindowGroup {

            // ============================================================
            // GLOBAL APP LAYER
            //
            // NavigationStack is ONE layer.
            // Arrival banners / tips / splash sit ABOVE navigation.
            // ============================================================

            ZStack(alignment: .top) {

                // MARK: - Main Navigation

                NavigationStack(
                    path: $navigationModel.path
                ) {

                    ContentView()
                        .environmentObject(navigationModel)
                        .environmentObject(locationManager)
                        .environmentObject(breadcrumbStore)
                        .preferredColorScheme(preferredScheme)
                        .navigationDestination(
                            for: NavigationDestination.self
                        ) { destination in

                            switch destination {

                            // MARK: - Add User

                            case .addUser:

                                AddUserView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Login

                            case .login:

                                LoginView(
                                    onLogin: {

                                        navigationModel.path = [
                                            .content
                                        ]
                                    }
                                )
                                .environmentObject(
                                    navigationModel
                                )

                            // MARK: - Content

                            case .content:

                                ContentView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Dashboard

                            case .dashboard:

                                DashboardView(
                                    selectedTab:
                                        .constant(Tab.home)
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )
                                .environmentObject(
                                    breadcrumbStore
                                )

                            // MARK: - Add Breadcrumb

                            case .addBreadcrumb:

                                AddBreadcrumbView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Add Breadcrumb To Group

                            case .addBreadcrumbToGroup(
                                let groupName
                            ):

                                AddBreadcrumbView(
                                    preselectedGroupName:
                                        groupName
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Breadcrumb Detail

                            case .breadcrumbDetail(
                                let breadcrumb
                            ):

                                BreadcrumbDetailView(
                                    breadcrumb:
                                        breadcrumb
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Breadcrumb Detail IDs

                            case .breadcrumbDetailIDs(
                                let objectIDs,
                                let startIndex
                            ):

                                BreadcrumbDetailView(
                                    objectIDs:
                                        objectIDs,
                                    startIndex:
                                        startIndex
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Group Crumbs

                            case .groupCrumbs(
                                let groupName
                            ):

                                GroupCrumbsView(
                                    groupName:
                                        groupName
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Unnamed Pins

                            case .unnamedBreadcrumbs:

                                UnnamedPinsView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - All Pins

                            case .allBreadcrumbs:

                                AllBreadcrumbsView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Breadcrumb Map

                            case .breadcrumbMap(
                                let breadcrumb
                            ):

                                BreadcrumbMapView(
                                    breadcrumb:
                                        breadcrumb
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Want To Go Map

                            case .wantToGoMap:

                                WantToGoMapView()
                                    .environmentObject(
                                        navigationModel
                                    )

                            // MARK: - Want To Go List

                            case .wantToGoList:

                                WantToGoListView()
                                    .environmentObject(
                                        navigationModel
                                    )

                            // MARK: - Diagnostics

                            case .diagnostics:

                                DiagnosticsView()
                                    .environmentObject(
                                        diagnosticsStore
                                    )

                            // MARK: - Edit Breadcrumb

                            case .editBreadcrumb(
                                let breadcrumb
                            ):

                                EditBreadcrumbView(
                                    breadcrumb:
                                        breadcrumb
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Groups List

                            case .groupsList:

                                GroupsListView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Edit Profile

                            case .editProfile:

                                EditProfileView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Settings

                            case .settings:

                                SettingsView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Group Map

                            case .groupCrumbMap(
                                let groupBreadcrumbs
                            ):

                                GroupCrumbMapView(
                                    breadcrumbs:
                                        groupBreadcrumbs
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Navigate To Location

                            case .navigateToLocation(
                                let breadcrumb
                            ):

                                BreadcrumbNavigationView(
                                    breadcrumb:
                                        breadcrumb
                                )
                                .environmentObject(
                                    navigationModel
                                )
                                .environmentObject(
                                    locationManager
                                )

                            // MARK: - Recent Pins

                            case .recentBreadcrumbs:

                                RecentBreadcrumbsView()
                                    .environmentObject(
                                        navigationModel
                                    )
                                    .environmentObject(
                                        locationManager
                                    )

                            // MARK: - Favorites

                            case .favoritesBreadcrumbs:

                                FavoritesBreadcrumbView(
                                    breadcrumbs:
                                        breadcrumbStore
                                            .favorites,
                                    onTap: {
                                        breadcrumb in

                                        navigationModel
                                            .path
                                            .append(
                                                .breadcrumbDetail(
                                                    breadcrumb:
                                                        breadcrumb
                                                )
                                            )
                                    }
                                )
                                .environmentObject(
                                    breadcrumbStore
                                )
                                .environmentObject(
                                    navigationModel
                                )
                            }
                        }
                }


                // ============================================================
                // MARK: - Foreground Want To Go Arrival Banner
                // ============================================================

                if !showSplash,
                   let prompt =
                    arrivalManager.activeArrivalPrompt {

                    WantToGoArrivalBanner(
                        destinationName:
                            prompt.destinationName,

                        onHere: {

                            Task {

                                await arrivalManager
                                    .confirmActiveArrival()
                            }
                        },

                        onNotYet: {

                            withAnimation {

                                arrivalManager
                                    .dismissActiveArrival()
                            }
                        }
                    )
                    .padding(.top, 8)
                    .transition(
                        .move(edge: .top)
                            .combined(
                                with: .opacity
                            )
                    )
                    .zIndex(1000)
                }


                // ============================================================
                // MARK: - Contextual Tip Banner
                // ============================================================

                if !showSplash,
                   arrivalManager
                    .activeArrivalPrompt == nil,
                   let tip =
                    tipManager.activeTip,
                   tip.presentationStyle == .banner {

                    ContextualTipBannerView(
                        tip: tip,
                        onDismiss: {

                            withAnimation {

                                tipManager
                                    .dismissActiveTip()
                            }
                        }
                    )
                    .padding(.top, 8)
                    .transition(
                        .move(edge: .top)
                            .combined(
                                with: .opacity
                            )
                    )
                    .zIndex(900)
                }


                // ============================================================
                // MARK: - Splash Screen
                // ============================================================

                if showSplash {

                    SplashScreenView(
                        onFinished: {

                            withAnimation(
                                .easeInOut(
                                    duration: 0.35
                                )
                            ) {

                                showSplash = false
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(2000)
                }
            }

            // MARK: - AdMob Consent

            .task {

                await AdMobConsentManager
                    .shared
                    .gatherConsent()
            }

            // MARK: - Core Data

            .environment(
                \.managedObjectContext,
                persistenceController
                    .container
                    .viewContext
            )

            // MARK: - Global Environment Objects

            .environmentObject(
                navigationModel
            )

            .environmentObject(
                locationManager
            )

            .environmentObject(
                breadcrumbStore
            )

            .environmentObject(
                arrivalManager
            )

            .environmentObject(
                tipManager
            )

            .environmentObject(
                diagnosticsStore
            )

            .onAppear {

                switch scenePhase {

                case .active:
                    diagnosticsStore.updateAppState("Active")

                case .inactive:
                    diagnosticsStore.updateAppState("Inactive")

                case .background:
                    diagnosticsStore.updateAppState("Background")

                @unknown default:
                    diagnosticsStore.updateAppState("Unknown")
                }
            }
            
            // MARK: - Scene Phase

            .onChange(of: scenePhase) { _, newPhase in

                switch newPhase {

                case .active:

                    diagnosticsStore.updateAppState(
                        "Active"
                    )

                    locationManager.startUpdates()

                case .inactive:

                    diagnosticsStore.updateAppState(
                        "Inactive"
                    )

                    locationManager.stopUpdates()

                case .background:

                    diagnosticsStore.updateAppState(
                        "Background"
                    )

                    locationManager.stopUpdates()

                @unknown default:

                    diagnosticsStore.updateAppState(
                        "Unknown"
                    )
                }
            }
        }
    }


    // ============================================================
    // MARK: - Navigation Bar Appearance
    // ============================================================

    private func configureNavigationBarAppearance() {

        let appearance =
            UINavigationBarAppearance()

        appearance
            .configureWithOpaqueBackground()

        appearance.backgroundColor =
            UIColor(
                named: "Dark Blue"
            )

        appearance.titleTextAttributes = [

            .foregroundColor:
                UIColor(
                    named:
                        "Light Orange"
                )
                ?? .white
        ]

        appearance.largeTitleTextAttributes = [

            .foregroundColor:
                UIColor(
                    named:
                        "Light Orange"
                )
                ?? .white
        ]

        UINavigationBar
            .appearance()
            .standardAppearance =
            appearance

        UINavigationBar
            .appearance()
            .scrollEdgeAppearance =
            appearance

        UINavigationBar
            .appearance()
            .compactAppearance =
            appearance

        UINavigationBar
            .appearance()
            .tintColor =
            UIColor(
                named: "Dark Orange"
            )
    }
}
