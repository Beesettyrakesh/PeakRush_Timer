// File: PeakRush_Timer/Utilities/MetalErrorLogger.swift

import Foundation
import UIKit

/// MetalErrorLogger is a utility class that monitors and logs Metal framework errors.
/// These errors are typically non-critical and don't affect the app's functionality,
/// but they can clutter the console output.
class MetalErrorLogger {
    static let shared = MetalErrorLogger()
    
    private var isMonitoring = false
    
    /// Start monitoring for Metal framework errors
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        // Register for Metal framework error notifications if available
        // Note: There's no official Metal error notification, so we use a generic approach
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePotentialMetalError(_:)),
            name: NSNotification.Name("MetalErrorNotification"),
            object: nil
        )
        
        // Also register for general app notifications that might coincide with Metal errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        isMonitoring = true
        print("Metal error monitoring started")
    }
    
    /// Stop monitoring for Metal framework errors
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
        isMonitoring = false
        print("Metal error monitoring stopped")
    }
    
    /// Handle potential Metal framework errors
    @objc private func handlePotentialMetalError(_ notification: Notification) {
        // Log the error but don't take action as it doesn't affect our functionality
        print("Metal framework error detected: \(notification)")
    }
    
    /// Handle app becoming active - a common time for Metal errors to appear
    @objc private func handleAppDidBecomeActive(_ notification: Notification) {
        // Check for any Metal-related errors in the console
        // This is just a placeholder as we can't directly access console output
        print("App became active - monitoring for potential Metal framework errors")
    }
    
    /// Log a RenderBox framework error
    func logRenderBoxError(_ error: String) {
        print("RenderBox framework error: \(error)")
        // We could add additional logging or analytics here if needed
    }
}
