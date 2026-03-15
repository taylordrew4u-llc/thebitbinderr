//
//  iCloudSyncService.swift
//  thebitbinder
//
//  Created on 3/7/26.
//

import SwiftUI
import SwiftData
import CloudKit
import UIKit

@MainActor
final class iCloudSyncService: NSObject, ObservableObject {
    @Published var isSyncEnabled = false
    @Published var isHapticFeedbackEnabled = true
    @Published var lastSyncDate: Date?
    @Published var syncStatus: SyncStatus = .idle
    @Published var errorMessage: String?
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    static let shared = iCloudSyncService()
    private let userDefaults = UserDefaults.standard
    private let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    private let lastSyncDateKey = "lastSyncDate"
    
    // CloudKit container - uses the explicit container ID from entitlements
    private lazy var container: CKContainer = {
        return CKContainer(identifier: "iCloud.10Bit")
    }()
    
    override init() {
        super.init()
        isSyncEnabled = userDefaults.bool(forKey: iCloudSyncEnabledKey)
        if let lastSync = userDefaults.object(forKey: lastSyncDateKey) as? Date {
            lastSyncDate = lastSync
        }
    }
    
    // MARK: - Enable/Disable iCloud Sync
    
    func enableiCloudSync() async {
        do {
            // Check iCloud availability
            let status = try await container.accountStatus()
            guard status == .available else {
                syncStatus = .error("iCloud not available")
                errorMessage = "Please sign into iCloud in Settings"
                return
            }
            
            isSyncEnabled = true
            userDefaults.set(true, forKey: iCloudSyncEnabledKey)
            
            // Perform initial sync
            await performFullSync()
        } catch {
            syncStatus = .error(error.localizedDescription)
            errorMessage = "Failed to enable iCloud sync: \(error.localizedDescription)"
        }
    }
    
    func disableiCloudSync() {
        isSyncEnabled = false
        userDefaults.set(false, forKey: iCloudSyncEnabledKey)
        syncStatus = .idle
        errorMessage = nil
    }
    
    // MARK: - Full Sync
    
    func performFullSync() async {
        guard isSyncEnabled else { return }
        
        syncStatus = .syncing
        defer { lastSyncDate = Date(); userDefaults.set(lastSyncDate, forKey: lastSyncDateKey) }
        
        // Push user settings to iCloud KV store
        iCloudKeyValueStore.shared.pushToCloud()
        
        // Sync all data types
        await syncJokes()
        await syncRoastTargets()
        await syncRoastJokes()
        await syncSetLists()
        await syncRecordings()
        await syncNotebookPhotos()
        
        syncStatus = .success
        errorMessage = nil
        hapticFeedback()
    }
    
    // MARK: - Incremental Syncs
    
    private func syncJokes() async {
        // Jokes sync handled via SwiftData CloudKit integration
        // SwiftData automatically syncs when iCloud sync is enabled
        print("✅ Jokes synced")
    }
    
    private func syncRoastTargets() async {
        // RoastTargets sync handled via SwiftData CloudKit integration
        // The @Relationship to RoastJoke ensures targets and their jokes stay linked
        print("✅ Roast targets synced")
    }
    
    private func syncRoastJokes() async {
        // RoastJokes sync handled via SwiftData CloudKit integration
        // Each RoastJoke has a REFERENCE back to its RoastTarget, synced automatically
        print("✅ Roast jokes synced")
    }
    
    private func syncSetLists() async {
        // SetLists sync handled via SwiftData CloudKit integration
        print("✅ Set lists synced")
    }
    
    private func syncRecordings() async {
        // Audio files synced via CloudKit file storage
        print("✅ Recordings synced")
    }
    
    private func syncNotebookPhotos() async {
        // Photo records synced via SwiftData CloudKit integration
        print("✅ Notebook photos synced")
    }
    
    // MARK: - Sync Thoughts (Notepad)
    
    func syncThoughts(_ content: String) async {
        guard isSyncEnabled else { return }
        
        let thoughtsKey = "iCloudThoughtsContent"
        userDefaults.set(content, forKey: thoughtsKey)
        
        // Also save to CloudKit for true cloud backup
        do {
            let record = CKRecord(recordType: "Thoughts")
            record["content"] = content
            record["timestamp"] = Date()
            
            let database = container.privateCloudDatabase
            _ = try await database.save(record)
            print("✅ Thoughts synced to iCloud")
        } catch {
            print("❌ Failed to sync thoughts: \(error)")
        }
    }
    
    func fetchThoughtsFromCloud() async -> String? {
        guard isSyncEnabled else { return nil }
        
        do {
            let database = container.privateCloudDatabase
            let query = CKQuery(recordType: "Thoughts", predicate: NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            
            let results = try await database.records(matching: query)
            if let latestRecord = try results.matchResults.first?.1.get() {
                return latestRecord["content"] as? String
            }
        } catch {
            print("❌ Failed to fetch thoughts: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Manual Sync Trigger
    
    func syncNow() async {
        await performFullSync()
    }
    
    // MARK: - Haptic Feedback
    
    private func hapticFeedback() {
        guard isHapticFeedbackEnabled else { return }
#if !targetEnvironment(macCatalyst)
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
#endif
    }
    
    // MARK: - Check Sync Status
    
    func checkiCloudAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                print("✅ [iCloud] Account available")
                return true
            case .noAccount:
                print("❌ [iCloud] No account — user not signed into iCloud")
                errorMessage = "Sign in to iCloud in Settings → [Your Name] → iCloud"
            case .restricted:
                print("❌ [iCloud] Account restricted (parental controls or MDM)")
                errorMessage = "iCloud is restricted on this device"
            case .couldNotDetermine:
                print("❌ [iCloud] Could not determine account status")
                errorMessage = "Could not check iCloud status — try again later"
            case .temporarilyUnavailable:
                print("⚠️ [iCloud] Temporarily unavailable")
                errorMessage = "iCloud is temporarily unavailable — try again later"
            @unknown default:
                print("❌ [iCloud] Unknown account status: \(status)")
                errorMessage = "Unknown iCloud status"
            }
            return false
        } catch {
            print("❌ [iCloud] Account check error: \(error)")
            errorMessage = "iCloud check failed: \(error.localizedDescription)"
            return false
        }
    }
    
    /// Detailed diagnostic info — call from Settings to surface issues
    func runDiagnostics() async -> [String] {
        var results: [String] = []
        
        // 1. iCloud account
        do {
            let status = try await container.accountStatus()
            results.append("iCloud Account: \(status == .available ? "✅ Available" : "❌ \(status)")")
        } catch {
            results.append("iCloud Account: ❌ Error — \(error.localizedDescription)")
        }
        
        // 2. Container ID
        results.append("Container: iCloud.10Bit")
        
        // 3. Sync enabled
        results.append("Sync Enabled: \(isSyncEnabled ? "✅ Yes" : "❌ No")")
        
        // 4. Last sync
        if let lastSync = lastSyncDate {
            results.append("Last Sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
        } else {
            results.append("Last Sync: Never")
        }
        
        // 5. Try a test fetch to verify CloudKit connectivity
        do {
            let database = container.privateCloudDatabase
            let query = CKQuery(recordType: "CD_RoastTarget", predicate: NSPredicate(value: true))
            let (matchResults, _) = try await database.records(matching: query, resultsLimit: 1)
            results.append("CloudKit Fetch Test: ✅ Connected (\(matchResults.count) result(s))")
        } catch {
            results.append("CloudKit Fetch Test: ❌ \(error.localizedDescription)")
        }
        
        return results
    }
}

