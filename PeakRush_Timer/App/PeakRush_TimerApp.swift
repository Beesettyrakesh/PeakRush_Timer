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
