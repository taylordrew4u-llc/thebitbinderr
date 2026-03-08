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

        // Store URL — all fallback paths use the same file so data is never orphaned
        let storeURL = URL.applicationSupportDirectory.appending(path: "thebitbinder.store")

        // 1️⃣ Try persistent + CloudKit
        do {
            let config = ModelConfiguration(
                "BitBinderStore",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .automatic
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ [ModelContainer] Persistent + CloudKit ready")
            return container
        } catch {
            print("⚠️ [ModelContainer] CloudKit store failed: \(error)")
        }

        // 2️⃣ Same file, no CloudKit — preserves existing data
        do {
            let config = ModelConfiguration(
                "BitBinderStore",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ [ModelContainer] Persistent (local only) ready")
            return container
        } catch {
            print("⚠️ [ModelContainer] Local store failed: \(error)")
        }

        // 3️⃣ Fresh file, no CloudKit — schema may have changed beyond migration
        do {
            let freshURL = URL.applicationSupportDirectory.appending(path: "thebitbinder_fresh.store")
            let config = ModelConfiguration(
                "BitBinderStoreFresh",
                schema: schema,
                url: freshURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: [config])
            print("⚠️ [ModelContainer] Fresh persistent store created (old data in thebitbinder.store)")
            return container
        } catch {
            print("❌ [ModelContainer] Fresh store also failed: \(error)")
        }

        // 4️⃣ In-memory — app works but nothing persists
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            print("❌ [ModelContainer] In-memory fallback — data will NOT persist")
            return container
        } catch {
            fatalError("Cannot create any ModelContainer: \(error)")
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
