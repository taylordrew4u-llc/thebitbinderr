//
//  MemoryManager.swift
//  thebitbinder
//
//  Memory management utility for the app
//

import UIKit
import Foundation

/// Centralized memory management for the app
final class MemoryManager {
    static let shared = MemoryManager()
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleBackgroundTransition()
        }
    }
    
    /// Called when system sends memory warning
    func handleMemoryWarning() {
        print("⚠️ [MemoryManager] Memory warning received - clearing caches")
        
        // Perform cache clearing off the main thread to avoid UI hangs
        DispatchQueue.global(qos: .utility).async {
            // Clear image caches
            ImageCache.shared.clearCache()
            
            // Clear URL caches
            URLCache.shared.removeAllCachedResponses()
            
            // Force a garbage collection hint
            autoreleasepool { }
            
            // Notify listeners on the main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .appMemoryWarning, object: nil)
                print("✅ [MemoryManager] Caches cleared")
            }
        }
    }
    
    /// Called when app enters background
    func handleBackgroundTransition() {
        print("📱 [MemoryManager] App entering background - reducing memory footprint")
        
        // Perform cache clearing off the main thread
        DispatchQueue.global(qos: .utility).async {
            // Clear image cache to free memory while in background
            ImageCache.shared.clearCache()
            
            // Clear URL cache
            URLCache.shared.removeAllCachedResponses()
        }
    }
    
    /// Call this to proactively reduce memory usage
    func reduceMemoryUsage() {
        handleMemoryWarning()
    }
    
    /// Report current memory usage (for debugging)
    func reportMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            print("📊 [MemoryManager] Memory usage: \(String(format: "%.1f", usedMB)) MB")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let appMemoryWarning = Notification.Name("appMemoryWarning")
}
