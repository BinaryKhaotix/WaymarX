//
//  BreadcrumbRowView.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/17/24.
//
import SwiftUI

struct BreadcrumbRowView: View {
    let breadcrumb: Breadcrumb

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(breadcrumb.name ?? "Unnamed Pin")
                    .font(.headline)
                    .foregroundColor(Color("Dark Orange"))
                    .lineLimit(1)
                Text(breadcrumb.crmGroup?.groupName ?? "No Group")
                    .font(.subheadline)
                    .foregroundColor(Color("Light Orange").opacity(0.7))
                if let dateDropped = breadcrumb.dateDropped {
                    Text(formattedDate(dateDropped))
                        .font(.caption)
                        .foregroundColor(Color("Light Orange").opacity(0.7))
                }
            }

            Spacer()

            if breadcrumb.isFavorite {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                    .font(.title2)
            }
            Image(systemName: "chevron.right")
                .foregroundColor(Color("Light Orange").opacity(0.7))
        }
        .padding(.vertical, 6) // Compact vertical spacing
        .padding(.horizontal, 10)
        .background(Color("Dark Blue"))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}



//
//struct BreadcrumbRowView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        HStack {
//            // Name and Date Section
//            VStack(alignment: .leading, spacing: 2) { // Minimal spacing
//                Text(breadcrumb.name ?? "Unnamed Crumb")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//                    .lineLimit(1)
//
//                Text(breadcrumb.crmGroup?.groupName ?? "No Group")
//                    .font(.subheadline)
//                    .foregroundColor(Color("Light Orange").opacity(0.7))
//                    .lineLimit(1)
//
//                if let dateDropped = breadcrumb.dateDropped {
//                    Text(formattedDate(dateDropped))
//                        .font(.caption)
//                        .foregroundColor(Color("Light Orange").opacity(0.7))
//                }
//            }
//
//            Spacer()
//
//            // Heart Icon for Favorites
//            if breadcrumb.isFavorite {
//                Image(systemName: "heart.fill")
//                    .foregroundColor(.red)
//                    .font(.title3)
//            }
//
//            // Chevron
//            Image(systemName: "chevron.right")
//                .foregroundColor(Color("Light Orange").opacity(0.7))
//        }
//        .padding(.vertical, 4) // Adjust row height spacing
//        .padding(.horizontal, 5) // Horizontal padding
//        .frame(maxWidth: .infinity) // Make the row full width
//        .background(Color("Dark Blue")) // Tile background
//        .cornerRadius(10)
//        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
//    }
//
//    // Helper function to format the date
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//}


//struct BreadcrumbRowView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        HStack {
//            // Name and Date Section
//            VStack(alignment: .leading, spacing: 3) { // Reduced spacing
//                Text(breadcrumb.name ?? "Unnamed Crumb")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//                    .lineLimit(1)
//
//                Text(breadcrumb.crmGroup?.groupName ?? "No Group")
//                    .font(.subheadline)
//                    .foregroundColor(Color("Light Orange").opacity(0.7))
//                    .lineLimit(1)
//
//                if let dateDropped = breadcrumb.dateDropped {
//                    Text(formattedDate(dateDropped))
//                        .font(.caption)
//                        .foregroundColor(Color("Light Orange").opacity(0.7))
//                }
//            }
//
//            Spacer()
//
//            // Heart Icon for Favorites
//            if breadcrumb.isFavorite {
//                Image(systemName: "heart.fill")
//                    .foregroundColor(.red)
//                    .font(.title2)
//            }
//
//            // Chevron
//            Image(systemName: "chevron.right")
//                .foregroundColor(Color("Light Orange").opacity(0.7))
//        }
//        .padding(.vertical, 3) // Reduced vertical padding
//        .padding(.horizontal, 5) // Reduced horizontal padding
//        .frame(maxWidth: .infinity) // Ensure full width
//        .background(Color("Dark Blue")) // Tile background
//        .cornerRadius(10)
//        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
//    }
//
//    // Helper function to format the date
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//}



//
//
//struct BreadcrumbRowView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        HStack {
//            // Name and Date Section
//            VStack(alignment: .leading, spacing: 3) { // Reduced spacing
//                Text(breadcrumb.name ?? "Unnamed Crumb")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//                    .lineLimit(1)
//
//                Text(breadcrumb.crmGroup?.groupName ?? "No Group")
//                    .font(.subheadline)
//                    .foregroundColor(Color("Light Orange").opacity(0.7))
//                    .lineLimit(1)
//
//                if let dateDropped = breadcrumb.dateDropped {
//                    Text(formattedDate(dateDropped))
//                        .font(.caption)
//                        .foregroundColor(Color("Light Orange").opacity(0.7))
//                }
//            }
//
//            Spacer()
//
//            // Heart Icon for Favorites
//            if breadcrumb.isFavorite {
//                Image(systemName: "heart.fill")
//                    .foregroundColor(.red)
//                    .font(.title2)
//            }
//
//            // Chevron
//            Image(systemName: "chevron.right")
//                .foregroundColor(Color("Light Orange").opacity(0.7))
//        }
//        .padding(.vertical, 5) // Adjust vertical padding
//        .padding(.horizontal, 10) // Adjust horizontal padding
//        .background(Color("Dark Blue")) // Tile background
//        .cornerRadius(10)
//        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
//    }
//
//    // Helper function to format the date
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//}



//struct BreadcrumbRowView: View {
//    let breadcrumb: Breadcrumb
//
//    var body: some View {
//        HStack {
//            // Name and Date Section
//            VStack(alignment: .leading, spacing: 5) {
//                Text(breadcrumb.name ?? "Unnamed Crumb")
//                    .font(.headline)
//                    .foregroundColor(Color("Dark Orange"))
//                    .lineLimit(1)
//
//                Text(breadcrumb.crmGroup?.groupName ?? "No Group")
//                    .font(.subheadline)
//                    .foregroundColor(Color("Light Orange").opacity(0.7))
//                    .lineLimit(1)
//
//                if let dateDropped = breadcrumb.dateDropped {
//                    Text(formattedDate(dateDropped))
//                        .font(.subheadline)
//                        .foregroundColor(Color("Light Orange").opacity(0.7))
//                }
//            }
//
//            Spacer()
//
//            // Favorite Heart Icon
//            if breadcrumb.isFavorite {
//                Image(systemName: "heart.fill")
//                    .foregroundColor(.red)
//                    .font(.title3)
//            }
//
//            // Chevron
//            Image(systemName: "chevron.right")
//                .foregroundColor(Color("Light Orange").opacity(0.7))
//        }
//        .padding(.vertical, 6)  // Adjust vertical padding for spacing
//        .padding(.horizontal, 15) // Balanced horizontal padding
//        .background(Color("Dark Blue"))
//        .cornerRadius(15)
//        .shadow(color: Color.black.opacity(0.2), radius: 3)
//    }
//
//    private func formattedDate(_ date: Date) -> String {
//        let formatter = DateFormatter()
//        formatter.dateStyle = .medium
//        formatter.timeStyle = .short
//        return formatter.string(from: date)
//    }
//}
