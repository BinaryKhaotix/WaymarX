//
//  Iron_LadyApp.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/9/24.
//
import SwiftUI
import GoogleMobileAds
import UserMessagingPlatform

@main
struct IronLadyApp: App {
    let persistenceController = PersistenceController.shared

    @StateObject private var navigationModel = NavigationModel()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var breadcrumbStore = BreadcrumbStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var showSplash = true

    init() {
        WantToGoArrivalManager.shared.start()
        configureNavigationBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationModel.path) {

                ZStack {
                    // Your normal root
                    ContentView()
                        .environmentObject(navigationModel)
                        .environmentObject(locationManager)
                        .environmentObject(breadcrumbStore)

                    // Splash overlay (sits on top)
                    if showSplash {
                        SplashScreenView(onFinished: {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                showSplash = false
                            }
                        })
                        .transition(.opacity)
                        .zIndex(999)
                    }
                }
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .addUser:
                        AddUserView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .login:
                        LoginView(onLogin: {
                            navigationModel.path = [.content]
                        })
                        .environmentObject(navigationModel)

                    case .content:
                        ContentView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .dashboard:
                        DashboardView(selectedTab: .constant(Tab.home))
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)
                            .environmentObject(breadcrumbStore)

                    case .addBreadcrumb:
                        AddBreadcrumbView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)
                        
                    case .addBreadcrumbToGroup(let groupName):
                        AddBreadcrumbView(preselectedGroupName: groupName)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .breadcrumbDetail(let breadcrumb):
                        BreadcrumbDetailView(breadcrumb: breadcrumb)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .breadcrumbDetailIDs(let objectIDs, let startIndex):
                        BreadcrumbDetailView(objectIDs: objectIDs, startIndex: startIndex)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .groupCrumbs(let groupName):
                        GroupCrumbsView(groupName: groupName)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .unnamedBreadcrumbs(let breadcrumbs):
                        UnnamedPinsView(breadcrumbs: breadcrumbs)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .allBreadcrumbs:
                        AllBreadcrumbsView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .breadcrumbMap(let breadcrumb):
                        BreadcrumbMapView(breadcrumb: breadcrumb)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)
                        
                    case .wantToGoMap:
                        WantToGoMapView()
                            .environmentObject(navigationModel)

                    case .wantToGoList:
                        WantToGoListView()
                            .environmentObject(navigationModel)

                    case .editBreadcrumb(let breadcrumb):
                        EditBreadcrumbView(breadcrumb: breadcrumb)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .groupsList:
                        GroupsListView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .editProfile:
                        EditProfileView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .settings:
                        SettingsView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .groupCrumbMap(let groupBreadcrumbs):
                        GroupCrumbMapView(breadcrumbs: groupBreadcrumbs)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .navigateToLocation(let breadcrumb):
                        BreadcrumbNavigationView(breadcrumb: breadcrumb)
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .recentBreadcrumbs:
                        RecentBreadcrumbsView()
                            .environmentObject(navigationModel)
                            .environmentObject(locationManager)

                    case .favoritesBreadcrumbs:
                        FavoritesBreadcrumbView(
                            breadcrumbs: breadcrumbStore.favorites,
                            onTap: { breadcrumb in
                                navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
                            }
                        )
                        .environmentObject(breadcrumbStore)
                        .environmentObject(navigationModel)
                    }
                }
            }
            .task {
                await AdMobConsentManager.shared.gatherConsent()
            }
            // ✅ APPLY CORE DATA ONCE, HERE:
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(navigationModel)
            .environmentObject(locationManager)
            .environmentObject(breadcrumbStore)
            
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    locationManager.startUpdates()
                case .background, .inactive:
                    locationManager.stopUpdates()
                @unknown default:
                    break
                }
            }
        }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Dark Blue")
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(named: "Light Orange") ?? .white
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(named: "Light Orange") ?? .white
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().tintColor = UIColor(named: "Dark Orange")
    }
}







//import SwiftUI
//
//@main
//struct IronLadyApp: App {
//    let persistenceController = PersistenceController.shared
//    @StateObject private var navigationModel = NavigationModel()
//    @StateObject private var locationManager = LocationManager()
//    @StateObject private var breadcrumbStore = BreadcrumbStore()
//    @Environment(\.scenePhase) private var scenePhase
//
//    init() {
//        configureNavigationBarAppearance()
//    }
//
//    var body: some Scene {
//        WindowGroup {
//            NavigationStack(path: $navigationModel.path) {
//                ContentView()
//                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                    .environmentObject(navigationModel)
//                    .environmentObject(locationManager)
//                    .environmentObject(breadcrumbStore)
//                    .navigationDestination(for: NavigationDestination.self) { destination in
//                        switch destination {
//                        case .addUser:
//                            AddUserView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .login:
//                            LoginView(onLogin: {
//                                navigationModel.path = [.content]
//                            })
//                            .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                            .environmentObject(navigationModel)
//
//                        case .content:
//                            ContentView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .dashboard:
//                            DashboardView(selectedTab: .constant(Tab.home))
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//                                .environmentObject(breadcrumbStore)
//
//                        case .addBreadcrumb:
//                            AddBreadcrumbView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .breadcrumbDetail(let breadcrumb):
//                            BreadcrumbDetailView(breadcrumb: breadcrumb)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .groupCrumbs(let groupName):
//                            GroupCrumbsView(groupName: groupName)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .unnamedBreadcrumbs(let breadcrumbs):
//                            UnnamedPinsView(breadcrumbs: breadcrumbs)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .allBreadcrumbs:
//                            AllBreadcrumbsView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .breadcrumbMap(let breadcrumb):
//                            BreadcrumbMapView(breadcrumb: breadcrumb)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .editBreadcrumb(let breadcrumb):
//                            EditBreadcrumbView(breadcrumb: breadcrumb)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .groupsList:
//                            GroupsListView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .editProfile:
//                            EditProfileView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .settings:
//                            SettingsView()
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .groupCrumbMap(let groupBreadcrumbs):
//                            GroupCrumbMapView(breadcrumbs: groupBreadcrumbs)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//
//                        case .navigateToLocation(let breadcrumb):
//                            BreadcrumbNavigationView(breadcrumb: breadcrumb)
//                                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//                                .environmentObject(navigationModel)
//                                .environmentObject(locationManager)
//                            
//                        case .favoritesBreadcrumbs:
//                             FavoritesBreadcrumbView(
//                                 breadcrumbs: breadcrumbStore.favorites,
//                                 onTap: { breadcrumb in
//                                     navigationModel.path.append(.breadcrumbDetail(breadcrumb: breadcrumb))
//                                 }
//                             )
//                             .environmentObject(breadcrumbStore)
//                             .environmentObject(navigationModel)
//                        }
//                    }
//            }
//            .onChange(of: scenePhase) { newPhase in
//                switch newPhase {
//                case .active:
//                    locationManager.startUpdates()
//                case .background, .inactive:
//                    locationManager.stopUpdates()
//                default:
//                    break
//                }
//            }
//        }
//    }
//
//    private func configureNavigationBarAppearance() {
//        let appearance = UINavigationBarAppearance()
//        appearance.configureWithOpaqueBackground()
//        appearance.backgroundColor = UIColor(named: "Dark Blue")
//        appearance.titleTextAttributes = [
//            .foregroundColor: UIColor(named: "Light Orange") ?? .white
//        ]
//        appearance.largeTitleTextAttributes = [
//            .foregroundColor: UIColor(named: "Light Orange") ?? .white
//        ]
//
//        UINavigationBar.appearance().standardAppearance = appearance
//        UINavigationBar.appearance().scrollEdgeAppearance = appearance
//        UINavigationBar.appearance().compactAppearance = appearance
//        UINavigationBar.appearance().tintColor = UIColor(named: "Dark Orange")
//    }
//}



