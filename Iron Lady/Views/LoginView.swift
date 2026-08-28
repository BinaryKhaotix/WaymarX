//
//  LoginView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//

import SwiftUI
import CoreData

struct LoginView: View {
    var onLogin: () -> Void
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: CrumbUser.entity(),
        sortDescriptors: []
    ) private var users: FetchedResults<CrumbUser>
    
    @EnvironmentObject var navigationModel: NavigationModel
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginError: String? = nil
    
    // Keep track of "Stay Logged In" in UserDefaults
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("loggedInUsername") private var loggedInUsername: String = ""

    var body: some View {
        ZStack {
            // Background Image
            Image("SplashBackround")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                // App Title
                Text("WaymarX")
                    .font(.custom("Marker Felt", size: 64))
                    .foregroundColor(Color("Dark Orange"))
                    .padding(.bottom, 60)
                
                // Login Form
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .autocapitalization(.none)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                    
                    if let error = loginError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                    }

                    // Stay Logged In Toggle
                    Toggle("Stay Logged In", isOn: $isLoggedIn)
                        .toggleStyle(SwitchToggleStyle(tint: Color("Dark Orange")))
                        .padding(.top, 10)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 40)
                
                // Login Button
                Button(action: handleLogin) {
                    Text("Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color("Dark Orange"))
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                
                // Create Account Navigation
                Button(action: { navigationModel.path.append(.addUser) }) {
                    Text("Create Account")
                        .foregroundColor(Color("Dark Orange"))
                }
            }
        }
        .onAppear(perform: checkLoginStatus)
        .navigationBarHidden(true) // Hide navigation bar for login
    }
    
    private func checkLoginStatus() {
        if isLoggedIn, let user = users.first(where: { $0.username == loggedInUsername }) {
            // Automatically navigate to ContentView if "Stay Logged In" is enabled
            print("Stay Logged In: Navigating to ContentView...")
            navigationModel.path.append(.content)
        } else if users.isEmpty {
            // No user exists; navigate to AddUserView
            navigationModel.path.append(.addUser)
        }
    }
    
    private func handleLogin() {
        guard let user = users.first(where: { $0.username == username }) else {
            loginError = "Invalid username"
            return
        }
        
        if user.password == password {
            // Login successful
            print("Login successful, navigating to ContentView...")
            loggedInUsername = username
            isLoggedIn = true // Set "Stay Logged In" flag
            navigationModel.path.append(.content)
        } else {
            // Login failed
            loginError = "Invalid password"
        }
    }
}



//import SwiftUI
//import CoreData
//
//struct LoginView: View {
//    var onLogin: () -> Void
//    @Environment(\.managedObjectContext) private var viewContext
//    @FetchRequest(
//        entity: CrumbUser.entity(),
//        sortDescriptors: []
//    ) private var users: FetchedResults<CrumbUser>
//    
//    @EnvironmentObject var navigationModel: NavigationModel // Use NavigationModel for navigation
//    @State private var username: String = ""
//    @State private var password: String = ""
//    @State private var loginError: String? = nil
//    
//    var body: some View {
//        ZStack {
//            // Background Image
//            Image("SplashBackround")
//                .resizable()
//                .scaledToFill()
//                .edgesIgnoringSafeArea(.all)
//            
//            VStack(spacing: 20) {
//                // App Title
//                Text("Crumbz")
//                    .font(.custom("Marker Felt", size: 64))
//                    .foregroundColor(Color("Dark Orange"))
//                    .padding(.bottom, 60)
//                
//                // Login Form
//                VStack(spacing: 15) {
//                    TextField("Username", text: $username)
//                        .padding()
//                        .background(Color.white)
//                        .cornerRadius(10)
//                        .autocapitalization(.none)
//                        .textInputAutocapitalization(.never)
//                        .disableAutocorrection(true)
//
//                    SecureField("Password", text: $password)
//                        .padding()
//                        .background(Color.white)
//                        .cornerRadius(10)
//                    
//                    if let error = loginError {
//                        Text(error)
//                            .font(.footnote)
//                            .foregroundColor(.red)
//                    }
//                }
//                .padding(.horizontal, 40)
//                
//                // Login Button
//                Button(action: handleLogin) {
//                    Text("Login")
//                        .font(.headline)
//                        .foregroundColor(.white)
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Orange"))
//                        .cornerRadius(10)
//                }
//                .padding(.horizontal, 40)
//                
//                // Create Account Navigation
//                Button(action: { navigationModel.path.append(.addUser) }) {
//                    Text("Create Account")
//                        .foregroundColor(Color("Dark Orange"))
//                }
//            }
//        }
//        .onAppear(perform: checkUserExists)
//        .navigationBarHidden(true) // Hide navigation bar for login
//    }
//    
//    private func checkUserExists() {
//        if users.isEmpty {
//            // No user exists; navigate to AddUserView
//            navigationModel.path.append(.addUser)
//        }
//    }
//    
//    private func handleLogin() {
//        guard let user = users.first(where: { $0.username == username }) else {
//            loginError = "Invalid username"
//            return
//        }
//        
//        if user.password == password {
//            // Login successful, navigate to ContentView
//            print("Login successful, navigating to ContentView...")
//            navigationModel.path.append(.content)
//        } else {
//            // Login failed
//            loginError = "Invalid password"
//        }
//    }
//}


//import SwiftUI
//import CoreData
//
//struct LoginView: View {
//    var onLogin: () -> Void
//    @Environment(\.managedObjectContext) private var viewContext
//    @FetchRequest(
//        entity: CrumbUser.entity(),
//        sortDescriptors: []
//    ) private var users: FetchedResults<CrumbUser>
//    
//    @State private var username: String = ""
//    @State private var password: String = ""
//    @State private var showContentView = false
//    @State private var showAddUserView = false
//    @State private var loginError: String? = nil
//    
//    var body: some View {
//        NavigationView {
//            ZStack {
//                // Background Image
//                Image("SplashBackround")
//                    .resizable()
//                    .scaledToFill()
//                    .edgesIgnoringSafeArea(.all)
//                
//                VStack(spacing: 20) {
//                    // App Title
//                    Text("Crumbz")
//                        .font(.custom("Marker Felt", size: 64))
//                        .foregroundColor(Color("Dark Orange"))
//                        .padding(.bottom, 60)
//                    
//                    if showContentView {
//                        EmptyView() // Navigate to ContentView when login succeeds
//                    } else if showAddUserView {
//                        EmptyView() // Navigate to AddUserView when no user exists
//                    } else {
//                        // Login Form
//                        VStack(spacing: 15) {
//                            TextField("Username", text: $username)
//                                .padding()
//                                .background(Color.white)
//                                .cornerRadius(10)
//                                .autocapitalization(.none) // Disable automatic capitalization
//                                .textInputAutocapitalization(.never) // Required for iOS 15+
//                                .disableAutocorrection(true)
//
//                            SecureField("Password", text: $password)
//                                .padding()
//                                .background(Color.white)
//                                .cornerRadius(10)
//                            
//                            if let error = loginError {
//                                Text(error)
//                                    .font(.footnote)
//                                    .foregroundColor(.red)
//                            }
//                        }
//                        .padding(.horizontal, 40)
//                        
//                        // Login Button
//                        Button(action: handleLogin) {
//                            Text("Login")
//                                .font(.headline)
//                                .foregroundColor(.white)
//                                .frame(maxWidth: .infinity)
//                                .padding()
//                                .background(Color("Dark Orange"))
//                                .cornerRadius(10)
//                        }
//                        .padding(.horizontal, 40)
//                        
//                        // Create Account Navigation
//                        Button(action: { showAddUserView = true }) {
//                            Text("Create Account")
//                                .foregroundColor(Color("Dark Orange"))
//                        }
//                    }
//                }
//            }
//            .onAppear(perform: checkUserExists)
//            .navigationBarHidden(true) // Hide navigation bar for login
//            .fullScreenCover(isPresented: $showContentView) {
//                ContentView().environment(\.managedObjectContext, viewContext)
//            }
//            .fullScreenCover(isPresented: $showAddUserView) {
//                AddUserView().environment(\.managedObjectContext, viewContext)
//            }
//        }
//    }
//    
//    private func checkUserExists() {
//        if let _ = users.first {
//            // A user exists; show login screen
//            showContentView = false
//            showAddUserView = false
//        } else {
//            // No user exists; navigate to AddUserView
//            showAddUserView = true
//        }
//    }
//    
//    private func handleLogin() {
//        guard let user = users.first(where: { $0.username == username }) else {
//            loginError = "Invalid username"
//            return
//        }
//        
//        if user.password == password {
//            // Login successful
//            showContentView = true
//        } else {
//            // Login failed
//            loginError = "Invalid password"
//        }
//    }
//}



//import SwiftUI
//import CoreData
//
//struct LoginView: View {
//    @Environment(\.managedObjectContext) private var viewContext
//    @State private var username: String = ""
//    @State private var password: String = ""
//    @State private var userExists = false
//    @State private var crumbUser: CrumbUser?
//
//    @State private var showAddUserView = false
//    @State private var navigateToContentView = false
//
//    var body: some View {
//        ZStack {
//            // Fullscreen Background Image
//            Image("SplashBackround")
//                .resizable()
//                .scaledToFill()
//                .ignoresSafeArea()
//
//            VStack(spacing: 30) {
//                Text("Welcome to Crumbz")
//                    .font(.custom("Marker Felt", size: 50))
//                    .foregroundColor(Color("Dark Orange"))
//                    .padding()
//
//                // Username Input
//                TextField("Username", text: $username)
//                    .padding()
//                    .background(Color("Dark Blue").opacity(0.2))
//                    .cornerRadius(10)
//                    .padding(.horizontal)
//
//                // Password Input
//                SecureField("Password", text: $password)
//                    .padding()
//                    .background(Color("Dark Blue").opacity(0.2))
//                    .cornerRadius(10)
//                    .padding(.horizontal)
//
//                // Login Button
//                Button(action: checkLogin) {
//                    Text("Login")
//                        .frame(maxWidth: .infinity)
//                        .padding()
//                        .background(Color("Dark Blue"))
//                        .foregroundColor(.white)
//                        .cornerRadius(10)
//                        .padding(.horizontal)
//                }
//
//                NavigationLink("", destination: ContentView(), isActive: $navigateToContentView)
//            }
//        }
//        .fullScreenCover(isPresented: $showAddUserView) {
//            AddUserView()
//                .environment(\.managedObjectContext, viewContext)
//        }
//    }
//
//    private func checkLogin() {
//        let fetchRequest: NSFetchRequest<CrumbUser> = CrumbUser.fetchRequest()
//        fetchRequest.predicate = NSPredicate(format: "username == %@ AND password == %@", username, password)
//
//        do {
//            let result = try viewContext.fetch(fetchRequest)
//            if let user = result.first {
//                self.crumbUser = user
//                navigateToContentView = true
//            } else {
//                showAddUserView = true // No user found, add new user
//            }
//        } catch {
//            print("Failed to fetch user: \(error.localizedDescription)")
//        }
//    }
//}
