//
//  StartupView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/27/24.
//

import SwiftUI

struct StartupView: View {
    @EnvironmentObject var navigationModel: NavigationModel
    @FetchRequest(
        entity: CrumbUser.entity(),
        sortDescriptors: []
    ) private var users: FetchedResults<CrumbUser>
    
    // AppStorage to check for "Stay Logged In" and the logged-in user
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""

    var body: some View {
        VStack {
            if users.isEmpty {
                Text("No user found. Redirecting to Create User...")
                    .onAppear {
                        navigateToAddUser()
                    }
            } else if isLoggedIn, let _ = users.first(where: { $0.username == loggedInUsername }) {
                Text("Stay Logged In enabled. Redirecting to ContentView...")
                    .onAppear {
                        navigateToContentView()
                    }
            } else {
                Text("User found. Redirecting to Login...")
                    .onAppear {
                        navigateToLogin()
                    }
            }
        }
        .onAppear {
            navigateBasedOnUserStatus()
        }
    }

    private func navigateBasedOnUserStatus() {
        if users.isEmpty {
            navigationModel.path = [.addUser]
        } else if isLoggedIn, let _ = users.first(where: { $0.username == loggedInUsername }) {
            navigationModel.path = [.content]
        } else {
            navigationModel.path = [.login]
        }
    }

    private func navigateToAddUser() {
        if !navigationModel.path.contains(.addUser) {
            navigationModel.path.append(.addUser)
        }
    }

    private func navigateToLogin() {
        if !navigationModel.path.contains(.login) {
            navigationModel.path.append(.login)
        }
    }

    private func navigateToContentView() {
        if !navigationModel.path.contains(.content) {
            navigationModel.path.append(.content)
        }
    }
}


//import SwiftUI
//
//struct StartupView: View {
//    @EnvironmentObject var navigationModel: NavigationModel
//    @FetchRequest(
//        entity: CrumbUser.entity(),
//        sortDescriptors: []
//    ) private var users: FetchedResults<CrumbUser>
//
//    var body: some View {
//        VStack {
//            if users.isEmpty {
//                Text("No user found. Redirecting to Create User...")
//                    .onAppear {
//                        navigateToAddUser()
//                    }
//            } else {
//                Text("User found. Redirecting to Login...")
//                    .onAppear {
//                        navigateToLogin()
//                    }
//            }
//        }
//        .onAppear {
//            navigateBasedOnUserStatus()
//        }
//    }
//
//    private func navigateBasedOnUserStatus() {
//        if users.isEmpty {
//            navigationModel.path = [.addUser]
//        } else {
//            navigationModel.path = [.login]
//        }
//    }
//
//    private func navigateToAddUser() {
//        if !navigationModel.path.contains(.addUser) {
//            navigationModel.path.append(.addUser)
//        }
//    }
//
//    private func navigateToLogin() {
//        if !navigationModel.path.contains(.login) {
//            navigationModel.path.append(.login)
//        }
//    }
//}


//import SwiftUI
//
//struct StartupView: View {
//    @EnvironmentObject var navigationModel: NavigationModel
//    @State private var isUserDefined = false // Replace with real logic to check for user
//    @FetchRequest(
//        entity: CrumbUser.entity(),
//        sortDescriptors: []
//    ) private var users: FetchedResults<CrumbUser>
//    
//
//
//
//    var body: some View {
//        VStack {
//            if isUserDefined {
//                Button("Proceed to Login") {
//                    navigationModel.path.append(.login)
//                }
//                .buttonStyle(.borderedProminent)
//            } else {
//                Button("Create New User") {
//                    navigationModel.path.append(.addUser)
//                }
//                .buttonStyle(.borderedProminent)
//            }
//        }
//        .onAppear {
//            navigateBasedOnUserStatus()
//        }
//    }
//
//    private func navigateBasedOnUserStatus() {
//        if users.isEmpty {
//            // No user exists, navigate to AddUserView
//            navigationModel.path.append(.addUser)
//        } else {
//            // User exists, navigate to LoginView
//            navigationModel.path.append(.login)
//        }
//    }
//}
