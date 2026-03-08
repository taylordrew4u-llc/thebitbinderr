//
//  RoastJoke.swift
//  thebitbinder
//
//  A single roast joke written for a specific person (RoastTarget).
//

import Foundation
import SwiftData

@Model
final class RoastJoke {
    var id: UUID
    var content: String
    var title: String
    var dateCreated: Date
    var dateModified: Date

    /// The person this roast is about
    var target: RoastTarget?

    init(content: String, title: String = "", target: RoastTarget? = nil) {
        self.id = UUID()
        self.content = content
        self.title = title.isEmpty ? "Untitled Roast" : title
        self.dateCreated = Date()
        self.dateModified = Date()
        self.target = target
    }
}
