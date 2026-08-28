//
//  relativeTimeString.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/13/24.
//
import SwiftUI


private func relativeTimeString(from date: Date) -> String {
    let now = Date()
    let timeInterval = now.timeIntervalSince(date)

    // Time constants
    let minute: TimeInterval = 60
    let hour: TimeInterval = minute * 60
    let day: TimeInterval = hour * 24
    let week: TimeInterval = day * 7
    let month: TimeInterval = day * 30
    let year: TimeInterval = day * 365

    // Calculate relative time
    if timeInterval >= year {
        let years = Int(timeInterval / year)
        return "\(years) \(years == 1 ? "year" : "years") ago"
    } else if timeInterval >= month {
        let months = Int(timeInterval / month)
        return "\(months) \(months == 1 ? "month" : "months") ago"
    } else if timeInterval >= week {
        let weeks = Int(timeInterval / week)
        return "\(weeks) \(weeks == 1 ? "week" : "weeks") ago"
    } else if timeInterval >= day {
        let days = Int(timeInterval / day)
        return "\(days) \(days == 1 ? "day" : "days") ago"
    } else if timeInterval >= hour {
        let fractionalHours = timeInterval / hour
        let formattedHours = fractionalHours < 2
            ? String(format: "%.1f", fractionalHours) // Show 1 decimal place for hours < 2
            : String(Int(fractionalHours))           // Show whole numbers for hours >= 2
        return "\(formattedHours) \(fractionalHours < 2 ? "hour" : "hours") ago"
    } else if timeInterval >= minute {
        let minutes = Int(timeInterval / minute)
        return "\(minutes) \(minutes == 1 ? "min" : "mins") ago"
    } else {
        return timeInterval < 10 ? "Just now" : "\(Int(timeInterval)) secs ago"
    }
}

