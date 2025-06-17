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
        setupAudioSession()
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Ensure audio session remains active in background
        setupAudioSession()
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Refresh audio session when returning to foreground
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            // Configure audio session for background playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured for background playback")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
}
