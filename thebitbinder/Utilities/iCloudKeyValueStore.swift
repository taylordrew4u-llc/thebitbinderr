//
//  iCloudKeyValueStore.swift
//  thebitbinder
//
//  Bridges NSUbiquitousKeyValueStore (iCloud KV) with UserDefaults so
//  @AppStorage and manual UserDefaults reads stay in sync across devices.
//

import Foundation
import Combine

/// Keys that should be synced to iCloud across devices
enum SyncedKeys {
    static let notepadText      = "notepadText"
    static let roastModeEnabled = "roastModeEnabled"
    static let tabOrder         = "tabOrder"
    static let jokesViewMode    = "jokesViewMode"
    static let iCloudSyncEnabled = "iCloudSyncEnabled"
    
    /// All keys that should be mirrored between UserDefaults and iCloud KV store
    static let all: [String] = [
        notepadText,
        roastModeEnabled,
        tabOrder,
        jokesViewMode,
        iCloudSyncEnabled,
    ]
}

/// Singleton that keeps UserDefaults and NSUbiquitousKeyValueStore in sync.
/// On launch it pulls from iCloud → local. On local writes it pushes to iCloud.
final class iCloudKeyValueStore {
    static let shared = iCloudKeyValueStore()
    
    private let cloud = NSUbiquitousKeyValueStore.default
    private let local = UserDefaults.standard
    
    private init() {
        // Listen for remote changes pushed from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cloudDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud
        )
        
        // Trigger initial sync from iCloud
        cloud.synchronize()
        pullFromCloud()
    }
    
    // MARK: - Write (local → iCloud)
    
    /// Set a string value and push to iCloud
    func set(_ value: String?, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }
    
    /// Set a bool value and push to iCloud
    func set(_ value: Bool, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }
    
    /// Set a Data value and push to iCloud
    func set(_ value: Data, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value, forKey: key)
        cloud.synchronize()
    }
    
    /// Set an integer value and push to iCloud
    func set(_ value: Int, forKey key: String) {
        local.set(value, forKey: key)
        cloud.set(value as NSNumber, forKey: key)
        cloud.synchronize()
    }
    
    // MARK: - Read
    
    func string(forKey key: String) -> String? {
        cloud.string(forKey: key) ?? local.string(forKey: key)
    }
    
    func bool(forKey key: String) -> Bool {
        cloud.bool(forKey: key)
    }
    
    func data(forKey key: String) -> Data? {
        cloud.data(forKey: key) ?? local.data(forKey: key)
    }
    
    // MARK: - Pull (iCloud → local)
    
    /// Pull all synced keys from iCloud into UserDefaults
    func pullFromCloud() {
        for key in SyncedKeys.all {
            if let cloudValue = cloud.object(forKey: key) {
                local.set(cloudValue, forKey: key)
            }
        }
        local.synchronize()
        print("☁️ [iCloudKV] Pulled \(SyncedKeys.all.count) keys from iCloud")
    }
    
    /// Push all synced keys from UserDefaults to iCloud
    func pushToCloud() {
        for key in SyncedKeys.all {
            if let localValue = local.object(forKey: key) {
                cloud.set(localValue, forKey: key)
            }
        }
        cloud.synchronize()
        print("☁️ [iCloudKV] Pushed \(SyncedKeys.all.count) keys to iCloud")
    }
    
    // MARK: - Remote Change Handler
    
    @objc private func cloudDidChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
            return
        }
        
        // Only process server changes and initial syncs
        if reason == NSUbiquitousKeyValueStoreServerChange ||
           reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            
            let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
            
            for key in changedKeys where SyncedKeys.all.contains(key) {
                if let value = cloud.object(forKey: key) {
                    local.set(value, forKey: key)
                }
            }
            local.synchronize()
            
            // Post notification so views can refresh
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .iCloudKVDidChange, object: nil, userInfo: ["keys": changedKeys])
            }
            
            print("☁️ [iCloudKV] Received remote changes for keys: \(changedKeys)")
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let iCloudKVDidChange = Notification.Name("iCloudKVDidChange")
}
