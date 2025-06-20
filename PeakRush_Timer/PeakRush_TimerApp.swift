import SwiftUI
import AVFoundation

@main
struct PeakRush_TimerApp: App {
    // Register app delegate for handling notifications and audio
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
        
        // Set up audio session for background playback
        AudioManager.shared.setupAudioSession()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // No need to reconfigure audio session here - AudioManager handles it
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // No need to reconfigure audio session here - AudioManager handles it
    }
}
