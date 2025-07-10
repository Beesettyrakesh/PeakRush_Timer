import Foundation
import UserNotifications
import UIKit

class NotificationService {
    
    // Track notification permission status
    private var notificationsAuthorized = false
    
    // Track pending notification identifiers
    private var pendingNotificationIdentifiers: [String] = []
    
    init() {
        requestNotificationPermission()
        
        // Register for app termination notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let currentStatus = settings.authorizationStatus
            
            if currentStatus == .authorized || currentStatus == .provisional {
                self?.notificationsAuthorized = true
                print("Notification permission already granted")
            } else if currentStatus == .notDetermined {
                // Request permission
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    self?.notificationsAuthorized = granted
                    
                    if granted {
                        print("Notification permission granted")
                    } else if let error = error {
                        print("Notification permission error: \(error.localizedDescription)")
                    } else {
                        print("Notification permission denied")
                    }
                }
            } else {
                print("Notification permission denied or restricted")
            }
        }
    }
    
    func sendLocalNotification(title: String, body: String) {
        guard notificationsAuthorized else {
            print("Cannot send notification - permission not granted")
            // Try requesting permission again
            requestNotificationPermission()
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add category for better reliability
        content.categoryIdentifier = "WORKOUT_COMPLETION"
        
        // Add thread identifier for grouping related notifications
        content.threadIdentifier = "com.peakrush.timer.workout"
        
        // Increase notification priority
        content.relevanceScore = 1.0
        
        // Generate a unique identifier
        let identifier = "immediate-\(UUID().uuidString)"
            
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        // Track this notification
        pendingNotificationIdentifiers.append(identifier)
            
        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                print("Failed to send immediate notification: \(error.localizedDescription)")
            } else {
                print("Immediate notification scheduled with identifier: \(identifier)")
                
                // Remove from tracking after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.pendingNotificationIdentifiers.removeAll { $0 == identifier }
                }
            }
        }
    }
    
    func scheduleNotification(title: String, body: String, timeInterval: TimeInterval, identifier: String) {
        guard notificationsAuthorized else {
            print("Cannot schedule notification - permission not granted")
            // Try requesting permission again
            requestNotificationPermission()
            return
        }
        
        // Cancel any existing notification with this identifier
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // Add category for better reliability
        content.categoryIdentifier = "WORKOUT_COMPLETION"
        
        // Add thread identifier for grouping related notifications
        content.threadIdentifier = "com.peakrush.timer.workout"
        
        // Increase notification priority
        content.relevanceScore = 1.0
        
        // For better reliability with system termination, schedule two notifications:
        // 1. The main notification at the requested time
        // 2. A backup notification slightly later
        
        // Main notification
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: timeInterval,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        // Track this notification
        pendingNotificationIdentifiers.append(identifier)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled with identifier: \(identifier) for \(timeInterval) seconds from now")
            }
        }
        
        // Backup notification (only for longer intervals)
        if timeInterval > 30 {
            let backupIdentifier = "\(identifier)-backup"
            let backupTrigger = UNTimeIntervalNotificationTrigger(
                timeInterval: timeInterval + 15, // 15 seconds later
                repeats: false
            )
            
            // Create a copy of the content
            let backupContent = content.mutableCopy() as! UNMutableNotificationContent
            backupContent.title = title // Same title
            
            // Modify the body slightly to indicate it's a backup
            backupContent.body = "\(body) (Reminder)"
            
            let backupRequest = UNNotificationRequest(
                identifier: backupIdentifier,
                content: backupContent,
                trigger: backupTrigger
            )
            
            // Track this notification
            pendingNotificationIdentifiers.append(backupIdentifier)
            
            UNUserNotificationCenter.current().add(backupRequest) { error in
                if let error = error {
                    print("Failed to schedule backup notification: \(error.localizedDescription)")
                } else {
                    print("Backup notification scheduled with identifier: \(backupIdentifier)")
                }
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotificationIdentifiers.removeAll()
        print("All pending notifications cancelled")
    }
    
    func cancelNotification(withIdentifier identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        pendingNotificationIdentifiers.removeAll { $0 == identifier }
        
        // Also cancel any backup notification
        let backupIdentifier = "\(identifier)-backup"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [backupIdentifier])
        pendingNotificationIdentifiers.removeAll { $0 == backupIdentifier }
        
        print("Cancelled notification with identifier: \(identifier)")
    }
    
    // Handle app termination
    @objc private func handleAppWillTerminate() {
        // If we have pending notifications, ensure they're still scheduled
        if !pendingNotificationIdentifiers.isEmpty {
            print("App terminating with \(pendingNotificationIdentifiers.count) pending notifications")
            
            // We could potentially reschedule critical notifications here,
            // but there's limited time during termination
        }
    }
    
    // Setup notification categories for better handling
    func setupNotificationCategories() {
        let workoutCategory = UNNotificationCategory(
            identifier: "WORKOUT_COMPLETION",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([workoutCategory])
    }
}
