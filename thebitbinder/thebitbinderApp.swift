//
//  thebitbinderApp.swift
//  thebitbinder
//
//  Created by Taylor Drew on 12/2/25.
//

import SwiftUI
import SwiftData

@main
struct thebitbinderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Joke.self,
            JokeFolder.self,
            Recording.self,
            SetList.self,
            NotebookPhotoRecord.self,
            RoastTarget.self,
            RoastJoke.self,
            BrainstormIdea.self,
        ])
        
        let fileManager = FileManager.default
        if let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true
        )

        // Attempt 1: Open persistent store (handles lightweight migration for new tables automatically)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("⚠️ [ModelContainer] Persistent store failed: \(error.localizedDescription)")
        }
        
        // Attempt 2: Delete the corrupted store file and try again
        // This only runs if the store is truly broken, not on a normal migration
        do {
            let storeURL = modelConfiguration.url
            let storePath = storeURL.path
            
            // Remove the main store file and associated WAL/SHM files
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = URL(fileURLWithPath: storePath + suffix)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try? fileManager.removeItem(at: fileURL)
                    print("🗑️ [ModelContainer] Removed: \(fileURL.lastPathComponent)")
                }
            }
            
            print("🔄 [ModelContainer] Retrying with fresh persistent store...")
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("❌ [ModelContainer] Fresh store also failed: \(error.localizedDescription)")
        }
        
        // Attempt 3: Last resort — in-memory store (data won't persist but app won't crash)
        do {
            print("⚠️ [ModelContainer] Falling back to in-memory store. Data will NOT persist.")
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: [inMemoryConfig])
        } catch {
            fatalError("Could not create ModelContainer at all: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                // Save any pending model context changes immediately
                try? sharedModelContainer.mainContext.save()
            case .active:
                // Nothing needed — SwiftData context is already live
                break
            default:
                break
            }
        }
    }
}
