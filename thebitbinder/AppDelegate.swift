import UIKit
import AVFoundation
import FirebaseCore
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize memory manager early
        _ = MemoryManager.shared
        
        // Configure Firebase synchronously on main thread.
        FirebaseApp.configure()
        
        // Set up snarky notification manager as the UNUserNotificationCenter delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        NotificationManager.shared.scheduleIfNeeded()
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Reschedule snarky notification if one was consumed
        NotificationManager.shared.scheduleIfNeeded()
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        MemoryManager.shared.handleMemoryWarning()
    }
}
