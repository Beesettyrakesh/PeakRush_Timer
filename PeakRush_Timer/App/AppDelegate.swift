import Foundation
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let notificationService = NotificationService()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Set up notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
                
                // Set up notification categories for better handling
                self.notificationService.setupNotificationCategories()
            } else if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            } else {
                print("Notification permission denied")
            }
        }
        
        // Set up audio session for background playback
        AudioManager.shared.setupAudioSession()
        
        // Register for low power mode notifications to optimize battery usage
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangePowerMode(_:)),
            name: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil
        )
        
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            print("App launched in Low Power Mode - optimizing for battery usage")
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // No need to reconfigure audio session here - AudioManager handles it
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // No need to reconfigure audio session here - AudioManager handles it
    }
    
    // Handle low power mode changes
    @objc func didChangePowerMode(_ notification: Notification) {
        if ProcessInfo.processInfo.isLowPowerModeEnabled {
            print("Device entered Low Power Mode - optimizing app for battery usage")
        } else {
            print("Device exited Low Power Mode - resuming normal operation")
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // Handle notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Allow notification to show even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification interactions
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle any notification response if needed
        completionHandler()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
