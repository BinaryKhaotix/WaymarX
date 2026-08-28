//
//  BottomNavigationBar.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/19/24.
//
import SwiftUI

enum Tab: Hashable {
    case home
    case dropCrumb
    case map
    case groups
    case profile
    case navigate
    case wantToGoMap
    case wantToGoList
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Tab
    @EnvironmentObject var navigationModel: NavigationModel

    // Optional closures for customizing button actions
    var onHome: (() -> Void)?
    var onDropCrumb: (() -> Void)?
    var onMap: (() -> Void)?
    var onGroups: (() -> Void)?
    var onProfile: (() -> Void)?
    var onNavigate: (() -> Void)?
    var onWantToGoMap: (() -> Void)?
    var onWantToGoList: (() -> Void)?

    // Visibility flags for buttons
    var showHome: Bool = true
    var showDropCrumb: Bool = true
    var showMap: Bool = true
    var showGroups: Bool = true
    var showProfile: Bool = true
    var showNavigate: Bool = false
    var showWantToGoMap: Bool = false
    var showWantToGoList: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visibleTabs, id: \.self) { tab in
                createButton(for: tab)
            }
        }
        .padding()
        .background(Color.white)
        .ignoresSafeArea(edges: .bottom)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Visible Tabs

    private var visibleTabs: [Tab] {
        var tabs: [Tab] = []

        if showHome { tabs.append(.home) }
        if showDropCrumb { tabs.append(.dropCrumb) }
        if showMap { tabs.append(.map) }
        if showGroups { tabs.append(.groups) }
        if showProfile { tabs.append(.profile) }
        if showNavigate { tabs.append(.navigate) }
        if showWantToGoMap { tabs.append(.wantToGoMap) }
        if showWantToGoList { tabs.append(.wantToGoList) }

        return tabs
    }

    // MARK: - Create Button for Tab

    @ViewBuilder
    private func createButton(for tab: Tab) -> some View {
        Button {
            handleTap(tab)
        } label: {
            VStack {
                Image(systemName: iconName(for: tab))
                    .font(.title2)

                Text(title(for: tab))
                    .font(.caption)
            }
            .foregroundColor(
                selectedTab == tab
                ? Color("Dark Orange")
                : Color("Dark Blue")
            )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Handle Tap

    private func handleTap(_ tab: Tab) {
        selectedTab = tab

        switch tab {

        case .home:
            navigationModel.path = [.dashboard]
            print("Home button pressed: Navigation stack cleared")
            onHome?()

        case .dropCrumb:
            if let onDropCrumb {
                onDropCrumb()
            } else {
                print("No action assigned to Drop Pin")
            }

        case .map:
            if let onMap {
                onMap()
            } else {
                print("No action assigned to Map")
            }

        case .groups:
            if let onGroups {
                onGroups()
            } else {
                print("No action assigned to Groups")
            }

        case .profile:
            if let onProfile {
                onProfile()
            } else {
                print("No action assigned to Profile")
            }

        case .navigate:
            if let onNavigate {
                onNavigate()
            } else {
                print("No action assigned to Navigate")
            }

        case .wantToGoMap:
            if let onWantToGoMap {
                onWantToGoMap()
            } else {
                print("No action assigned to Want to Go Map")
            }

        case .wantToGoList:
            if let onWantToGoList {
                onWantToGoList()
            } else {
                print("No action assigned to Want to Go List")
            }
        }
    }

    // MARK: - Icon

    private func iconName(for tab: Tab) -> String {
        switch tab {
        case .home:
            return "house.fill"

        case .dropCrumb:
            return "plus.circle.fill"

        case .map:
            return "map.fill"

        case .groups:
            return "person.3.fill"

        case .profile:
            return "person.fill"

        case .navigate:
            return "location.fill"

        case .wantToGoMap:
            return "mappin.and.ellipse"

        case .wantToGoList:
            return "list.bullet"
        }
    }

    // MARK: - Title

    private func title(for tab: Tab) -> String {
        switch tab {
        case .home:
            return "Home"

        case .dropCrumb:
            return "Drop Pin"

        case .map:
            return "Map"

        case .groups:
            return "Groups"

        case .profile:
            return "Profile"

        case .navigate:
            return "Navigate"

        case .wantToGoMap:
            return "Want to Go"

        case .wantToGoList:
            return "Want to Go"
        }
    }
}

struct BottomNavigationBar_Previews: PreviewProvider {
    static var previews: some View {
        BottomNavigationBar(
            selectedTab: .constant(.home),
            showHome: true,
            showDropCrumb: true,
            showMap: true,
            showGroups: true,
            showProfile: true,
            showWantToGoMap: true,
            showWantToGoList: true
        )
        .environmentObject(NavigationModel())
    }
}
