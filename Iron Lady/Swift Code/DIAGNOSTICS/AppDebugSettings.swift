//
//  AppDebugSettings.swift
//  Iron Lady
//
//  Created by Dino Grillo on 11/19/26.
//

enum AppDebugSettings {

    #if DEBUG
    static let marketingScreenshotMode = true
    #else
    static let marketingScreenshotMode = false
    #endif
}
