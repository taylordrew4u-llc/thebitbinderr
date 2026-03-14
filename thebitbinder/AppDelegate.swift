import UIKit
import AVFoundation
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize memory manager early
        _ = MemoryManager.shared
        
        // Initialize iCloud key-value sync (pulls remote values into UserDefaults)
        _ = iCloudKeyValueStore.shared
        
        // Set up snarky notification manager as the UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.scheduleIfNeeded()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Reschedule snarky notification if one was consumed
        NotificationManager.shared.scheduleIfNeeded()
        // Pull latest from iCloud
        iCloudKeyValueStore.shared.pullFromCloud()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Push local changes to iCloud
        iCloudKeyValueStore.shared.pushToCloud()
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        MemoryManager.shared.handleMemoryWarning()
    }
}
