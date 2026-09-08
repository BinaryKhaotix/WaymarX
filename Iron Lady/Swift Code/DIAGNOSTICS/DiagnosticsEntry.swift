//
//  DiagnosticsEntry.swift
//  Iron Lady
//
//  Created by Dino Grillo on 9/4/26.
//

import Foundation

struct DiagnosticsEntry: Identifiable, Codable, Equatable {

    let id: UUID
    let timestamp: Date
    let category: String
    let message: String

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.message = message
    }
}
