import Foundation
import UserNotifications
import UIKit

class NotificationService {
    
    // Track notification permission status
    private var notificationsAuthorized = false
    
    // Track pending notification identifiers
    private var pendingNotificationIdentifiers: [String] = []
    
    // Track sent notification history to prevent duplicates
    private var recentNotificationHistory: [(identifier: String, timestamp: Date)] = []
    private let notificationHistoryLimit = 10
    private let notificationDeduplicationWindow: TimeInterval = 30.0 // 30 seconds
    
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
        
        // Check for recent similar notifications to prevent duplicates
        let now = Date()
        let notificationKey = "\(title)|\(body)"
        
        // Clean up old notification history entries
        cleanupNotificationHistory()
        
        // Check if we've sent a similar notification recently
        if hasRecentlySentSimilarNotification(key: notificationKey, within: notificationDeduplicationWindow) {
            print("Skipping duplicate immediate notification - similar notification sent recently")
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
        
        // Generate a unique identifier with a key for deduplication
        let identifier = "immediate-\(notificationKey.hashValue)-\(UUID().uuidString)"
            
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
        
        // Track this notification
        pendingNotificationIdentifiers.append(identifier)
        
        // Add to notification history
        addToNotificationHistory(identifier: notificationKey, timestamp: now)
            
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
        
        // Check for recent similar notifications to prevent duplicates
        let notificationKey = "\(title)|\(body)"
        
        // Clean up old notification history entries
        cleanupNotificationHistory()
        
        // Check if we've sent a similar notification recently
        if hasRecentlySentSimilarNotification(key: notificationKey, within: notificationDeduplicationWindow) {
            print("Skipping scheduled notification - similar notification sent recently")
            return
        }
        
        // Cancel any existing notification with this identifier
        cancelNotification(withIdentifier: identifier)
        
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
        
        // Add user info to help with deduplication
        content.userInfo = [
            "scheduledAt": Date().timeIntervalSince1970,
            "notificationKey": notificationKey
        ]
        
        // Calculate the scheduled delivery time for logging
        let scheduledTime = Date().addingTimeInterval(timeInterval)
        
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
        
        // Add to notification history - use scheduled time as the timestamp
        addToNotificationHistory(identifier: notificationKey, timestamp: scheduledTime)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled with identifier: \(identifier) for \(timeInterval) seconds from now (at \(scheduledTime))")
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
            
            // Add user info to help with deduplication
            backupContent.userInfo = [
                "scheduledAt": Date().timeIntervalSince1970,
                "notificationKey": notificationKey,
                "isBackup": true
            ]
            
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
                    print("Backup notification scheduled with identifier: \(backupIdentifier) for \(timeInterval + 15) seconds from now")
                }
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pendingNotificationIdentifiers.removeAll()
        print("All pending notifications cancelled")
    }
    
    // MARK: - Notification History Management
    
    // Add a notification to the history
    private func addToNotificationHistory(identifier: String, timestamp: Date) {
        recentNotificationHistory.append((identifier: identifier, timestamp: timestamp))
        
        // Keep history size under control
        if recentNotificationHistory.count > notificationHistoryLimit {
            recentNotificationHistory.removeFirst()
        }
    }
    
    // Clean up old notification history entries
    private func cleanupNotificationHistory() {
        let now = Date()
        recentNotificationHistory = recentNotificationHistory.filter { 
            now.timeIntervalSince($0.timestamp) < notificationDeduplicationWindow
        }
    }
    
    // Check if we've sent a similar notification recently
    private func hasRecentlySentSimilarNotification(key: String, within timeWindow: TimeInterval) -> Bool {
        let now = Date()
        
        for entry in recentNotificationHistory {
            if entry.identifier == key && now.timeIntervalSince(entry.timestamp) < timeWindow {
                print("Found similar notification sent at \(entry.timestamp), \(now.timeIntervalSince(entry.timestamp)) seconds ago")
                return true
            }
        }
        
        return false
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
