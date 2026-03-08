import UIKit
import AVFoundation
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Initialize memory manager early
        _ = MemoryManager.shared
        
        // Firebase must configure on the main thread (GULAppDelegateSwizzler touches UIApplication).
        // Dispatch async so it doesn't block the first frame, but stays on main.
        DispatchQueue.main.async {
            FirebaseApp.configure()
        }
        return true
    }
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // Additional memory warning handling
        MemoryManager.shared.handleMemoryWarning()
    }
}
