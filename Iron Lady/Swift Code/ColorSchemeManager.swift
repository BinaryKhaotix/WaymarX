//
//  ColorSchemeManager.swift
//  Iron Lady
//
//  Created by Dino Grillo on 12/12/24.
//

import SwiftUI

struct AppColorScheme {
    let light: Color
    let dark: Color
    let backgroundLight: Color
    let backgroundDark: Color
    let tileBackgroundColor: Color
}

class ColorSchemeManager: ObservableObject {
    let colorSchemes: [AppColorScheme] = [
        //Scheme 1: Dark Orange and Dark Blue
        AppColorScheme(
            light: Color("Dark Orange"),
            dark: Color("Dark Orange"),
            backgroundLight: Color(.white),
            backgroundDark: Color(.white),
            tileBackgroundColor: Color("Dark Blue").opacity(0.7)
        ),

        // Scheme 2: Light Orange and Light Blue
        AppColorScheme(
            light: Color("Light Orange"),
            dark: Color("Light Orange"),
            backgroundLight: Color(.white),
            backgroundDark: Color(.white),
            tileBackgroundColor: Color("Dark Blue").opacity(0.7)
            )
        ]
//        ),
//
//        // Scheme 3: Green & Teal
//        AppColorScheme(
//            light: .green,
//            dark: .teal,
//            backgroundLight: Color(red: 0.9, green: 1.0, blue: 0.9), // Light mint
//            backgroundDark: Color(red: 0.0, green: 0.25, blue: 0.25) // Deep forest green
//        ),
//
//        // Scheme 4: Yellow & Brown
//        AppColorScheme(
//            light: .yellow,
//            dark: .brown,
//            backgroundLight: Color(red: 1.0, green: 1.0, blue: 0.8), // Soft beige
//            backgroundDark: Color(red: 0.3, green: 0.15, blue: 0.0)  // Dark chocolate
//        ),
//
//        // Scheme 5: Pink & Indigo
//        AppColorScheme(
//            light: .pink,
//            dark: .indigo,
//            backgroundLight: Color(red: 1.0, green: 0.9, blue: 1.0), // Light blush
//            backgroundDark: Color(red: 0.1, green: 0.0, blue: 0.3)   // Dark violet
//        )
//    ]
//        AppColorScheme(light: .red, dark: .orange, backgroundLight: .white, backgroundDark: .black),
//        AppColorScheme(light: .blue, dark: .purple, backgroundLight: .white, backgroundDark: .black),
//        AppColorScheme(light: .green, dark: .teal, backgroundLight: .white, backgroundDark: .black),
//        AppColorScheme(light: .yellow, dark: .brown, backgroundLight: .white, backgroundDark: .black),
//        AppColorScheme(light: .pink, dark: .indigo, backgroundLight: .white, backgroundDark: .black)
//    ]

    @AppStorage("selectedColorSchemeIndex") var selectedSchemeIndex: Int = 0

    var currentScheme: AppColorScheme {
        let scheme = colorSchemes[selectedSchemeIndex]
        print("Current Scheme: \(scheme)") // Debugging
        return scheme
    }
}
