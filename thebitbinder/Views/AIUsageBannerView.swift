//
//  AIUsageBannerView.swift
//  thebitbinder
//
//  Reusable UI that shows users how many free AI uses they have left today,
//  and a friendly "locked" state when they've run out.
//

import SwiftUI

// MARK: - Usage Banner (compact, sits at the top of AI views)

/// Shows "3 of 5 free AI uses left today" with a progress ring.
/// Turns red/locked when uses are exhausted.
struct AIUsageBanner: View {
    @ObservedObject private var tracker = FreeUsageTracker.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    .frame(width: 36, height: 36)
                
                Circle()
                    .trim(from: 0, to: 1 - tracker.usageProgress)
                    .stroke(
                        tracker.hasUsesRemaining ? Color.blue : Color.red,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: tracker.usageProgress)
                
                Text("\(tracker.remaining)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(tracker.hasUsesRemaining ? .blue : .red)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                if tracker.hasUsesRemaining {
                    Text("\(tracker.remaining) of \(tracker.dailyLimit) free AI uses left")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text("Resets daily at midnight")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Free AI uses are all used up")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    Text(resetCountdown)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !tracker.hasUsesRemaining {
                Image(systemName: "lock.fill")
                    .foregroundColor(.red)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(tracker.hasUsesRemaining
                      ? Color.blue.opacity(0.08)
                      : Color.red.opacity(0.08))
        )
        .padding(.horizontal)
    }
    
    private var resetCountdown: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Resets \(formatter.localizedString(for: tracker.resetsAt, relativeTo: Date()))"
    }
}

// MARK: - Locked Overlay (covers the action area when uses are gone)

/// Full-width overlay that explains usage is exhausted.
/// Place this conditionally over send-buttons or action areas.
struct AIUsageLockedView: View {
    @ObservedObject private var tracker = FreeUsageTracker.shared
    let featureName: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Daily Limit Reached")
                .font(.title3.bold())
            
            Text("You've used all \(tracker.dailyLimit) free \(featureName) for today.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Countdown
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.blue)
                Text(resetCountdown)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(20)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        )
        .padding()
    }
    
    private var resetCountdown: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Resets \(formatter.localizedString(for: tracker.resetsAt, relativeTo: Date()))"
    }
}

// MARK: - Inline Usage Pill (tiny, for toolbars or compact spaces)

/// A small capsule that reads "3 left" in blue, or "0 left" in red.
struct AIUsagePill: View {
    @ObservedObject private var tracker = FreeUsageTracker.shared
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tracker.hasUsesRemaining ? "sparkles" : "lock.fill")
                .font(.caption2)
            Text("\(tracker.remaining) left")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundColor(tracker.hasUsesRemaining ? .blue : .red)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(tracker.hasUsesRemaining
                      ? Color.blue.opacity(0.12)
                      : Color.red.opacity(0.12))
        )
    }
}

#Preview("Banner — Has Uses") {
    AIUsageBanner()
        .padding()
}

#Preview("Locked View") {
    AIUsageLockedView(featureName: "AI chats")
}

#Preview("Pill") {
    AIUsagePill()
}
