//
//  FreeUsageTracker.swift
//  thebitbinder
//
//  Tracks free AI usage across the app. Enforces daily limits
//  so users can see exactly how many free AI actions remain.
//

import Foundation
import Combine

/// The different AI features that consume free uses
enum AIFeatureType: String, CaseIterable {
    case chat          = "bitbuddy_chat"
    case autoOrganize  = "auto_organize"
    case jokeExtract   = "joke_extraction"
    case jokeAnalysis  = "joke_analysis"
    case orgSuggestion = "org_suggestion"
    
    var displayName: String {
        switch self {
        case .chat:          return "BitBuddy Chat"
        case .autoOrganize:  return "Auto-Organize"
        case .jokeExtract:   return "Joke Extraction"
        case .jokeAnalysis:  return "Joke Analysis"
        case .orgSuggestion: return "Organization Tips"
        }
    }
    
    var icon: String {
        switch self {
        case .chat:          return "sparkles"
        case .autoOrganize:  return "wand.and.stars"
        case .jokeExtract:   return "text.magnifyingglass"
        case .jokeAnalysis:  return "brain.head.profile"
        case .orgSuggestion: return "list.bullet.indent"
        }
    }
}

/// Error thrown when a user has exhausted their free uses
enum UsageLimitError: LocalizedError {
    case limitReached(feature: AIFeatureType, resetsAt: Date)
    
    var errorDescription: String? {
        switch self {
        case .limitReached(let feature, let resetsAt):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relative = formatter.localizedString(for: resetsAt, relativeTo: Date())
            return "You've used all your free \(feature.displayName) for today. Resets \(relative)."
        }
    }
}

/// Singleton that tracks and enforces free AI usage limits per day.
/// Publishes changes so SwiftUI views update in real time.
@MainActor
final class FreeUsageTracker: ObservableObject {
    
    static let shared = FreeUsageTracker()
    
    /// Thread-safe lock for usage mutations
    private let lock = NSLock()
    
    // MARK: - Configuration
    
    /// Maximum free AI uses per day (shared across all features)
    let dailyLimit: Int = 5
    
    // MARK: - Published State
    
    /// Total uses consumed today
    @Published private(set) var usedToday: Int = 0
    
    /// When the current usage window resets (next midnight)
    @Published private(set) var resetsAt: Date = Date()
    
    // MARK: - Computed
    
    /// How many free uses are left right now
    var remaining: Int {
        max(dailyLimit - usedToday, 0)
    }
    
    /// Whether the user has any uses left
    var hasUsesRemaining: Bool {
        remaining > 0
    }
    
    /// A friendly string like "3 of 5"
    var usageText: String {
        "\(remaining) of \(dailyLimit)"
    }
    
    /// Progress from 0…1 (1 = all used up)
    var usageProgress: Double {
        Double(usedToday) / Double(dailyLimit)
    }
    
    // MARK: - Persistence Keys
    
    private let usedCountKey   = "free_ai_used_count"
    private let lastResetKey   = "free_ai_last_reset_date"
    
    // MARK: - Init
    
    private init() {
        resetIfNewDay()
    }
    
    // MARK: - Public API
    
    /// Call before every AI action. Throws `UsageLimitError.limitReached` if the
    /// user is out of free uses. Otherwise increments the counter.
    func consumeUse(for feature: AIFeatureType) throws {
        lock.lock()
        defer { lock.unlock() }
        
        resetIfNewDay()
        
        guard hasUsesRemaining else {
            throw UsageLimitError.limitReached(feature: feature, resetsAt: resetsAt)
        }
        
        // Because this class is @MainActor, this mutation always happens on the main thread
        usedToday += 1
        persist()
        
        print("📊 [Usage] \(feature.displayName) used. \(remaining) of \(dailyLimit) remaining today.")
    }
    
    /// Check without consuming — useful for disabling buttons in the UI
    func canUse(_ feature: AIFeatureType) -> Bool {
        resetIfNewDay()
        return hasUsesRemaining
    }
    
    // MARK: - Day Reset Logic
    
    private func resetIfNewDay() {
        let calendar = Calendar.current
        let lastReset = UserDefaults.standard.object(forKey: lastResetKey) as? Date ?? .distantPast
        
        if !calendar.isDateInToday(lastReset) {
            // New day — reset counter
            usedToday = 0
            let now = Date()
            UserDefaults.standard.set(now, forKey: lastResetKey)
            persist()
            print("📊 [Usage] New day detected — usage counter reset to 0.")
        } else {
            // Same day — load persisted count
            usedToday = UserDefaults.standard.integer(forKey: usedCountKey)
        }
        
        // Calculate next reset (midnight tonight)
        resetsAt = calendar.startOfDay(for: Date()).addingTimeInterval(86400)
    }
    
    private func persist() {
        UserDefaults.standard.set(usedToday, forKey: usedCountKey)
    }
}
