// File: PeakRush_Timer/ViewModels/TimerRunViewModel.swift

import Foundation
import SwiftUI
import AVFoundation
import UserNotifications

/// TimerRunViewModel manages the execution of interval training timers,
/// including background operation with audio cues.
///
/// Background Audio System:
/// - When the app goes to background, warnings are scheduled based on the current timer state
/// - A background timer checks periodically if any warnings should be played
/// - The timer state continues to advance internally while in background
/// - When warnings are played, they use the current timer state to ensure accuracy
/// - This approach ensures users hear the correct audio cues even if the app remains
///   in the background for extended periods spanning multiple sets
class TimerRunViewModel: ObservableObject {
    @Published var timerModel: TimerModel
    
    // Published property to track phase transitions for UI animation control
    @Published var isPhaseTransitioning = false
    
    private var timer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lastActiveTimestamp: Date = Date()
    private var backgroundWarningTimes: [Date] = []
    private var backgroundCheckTimer: Timer?
    private var backgroundRefreshTimer: Timer? // Added for better resource management
    private var warningSoundDuration: Int = 0
    private var lastStateChangeTime: Date = Date()
    private var minimumBackgroundTime: TimeInterval = 3.0
    private var lastTimerFireTime: Date = Date()
    
    private var setCompletionWarningTriggered = false
    private var setCompletionWarningSeconds = 5
    
    private var playedSetCompletionWarnings: Set<Int> = []
    private var playedSetCompletionWarningsWithTime: [Int: Date] = [:]
    private var isInBackgroundMode = false
    private var hasScheduledCompletionNotification = false
    private var lastCompletionNotificationTime: Date? = nil
    private var scheduledNotificationCompletionTime: Date? = nil
    
    // Timer for managing phase transition animation state
    private var phaseTransitionTimer: Timer?
    
    // Background task management
    private var backgroundTaskExpirationHandler: (() -> Void)?
    private var backgroundTaskStartTime: Date?
    private var backgroundTaskRenewalTimer: Timer?
    
    // Battery optimization flags
    private var isLowPowerMode: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    
    // Enum to distinguish between warning types for background mode
    // Note: For setCompletion warnings, the stored setNumber is used only for scheduling.
    // The actual set number announced at playback time is determined by the current timer state.
    private enum WarningType {
        case phaseTransition
        case setCompletion(setNumber: Int)
    }
    
    // Structure to track scheduled warnings
    private struct ScheduledWarning {
        let time: Date
        let type: WarningType
    }
    
    private var scheduledWarnings: [ScheduledWarning] = []
    
    private let notificationService = NotificationService()
    private let audioManager = AudioManager.shared
    
    init(timerModel: TimerModel) {
        self.timerModel = timerModel
        prepareWarningSound()
    }
    
    // MARK: - Public Properties
    
    var circleColor: Color {
        if timerModel.isTimerCompleted {
            return Color.blue
        } else if !timerModel.isTimerRunning {
            return Color.gray
        } else {
            return timerModel.isCurrentIntensityLow ? Color.green : Color.red
        }
    }
    
    var intensityText: String {
        if !timerModel.isTimerRunning && !timerModel.isTimerCompleted {
            return "Ready"
        } else if timerModel.isTimerCompleted {
            return "Completed!"
        } else {
            return timerModel.isCurrentIntensityLow ? "Low Intensity" : "High Intensity"
        }
    }
    
    var intensityColor: Color {
        if timerModel.isTimerCompleted {
            return Color.blue
        } else if !timerModel.isTimerRunning {
            return Color.black
        } else {
            return timerModel.isCurrentIntensityLow ? Color.green : Color.red
        }
    }
    
    var iconColor: Color {
        if timerModel.isTimerCompleted {
            return Color.blue
        } else if !timerModel.isTimerRunning {
            return Color.gray
        } else {
            return timerModel.isCurrentIntensityLow ? Color.green : Color.red
        }
    }
    
    // MARK: - Timer Control Methods
    
    func initializeTimer() {
        timerModel.currentMinutes = timerModel.minutes
        timerModel.currentSeconds = timerModel.seconds
        timerModel.currentSet = 1
        timerModel.isTimerRunning = false
        timerModel.isTimerCompleted = false
        timerModel.isCurrentIntensityLow = timerModel.isLowIntensity
        timerModel.warningTriggered = false
        timerModel.lowIntensityCompleted = false
        timerModel.highIntensityCompleted = false
        setCompletionWarningTriggered = false
        backgroundWarningTimes = []
        scheduledWarnings = []
        playedSetCompletionWarnings = []
        playedSetCompletionWarningsWithTime = [:]
        isInBackgroundMode = false
        hasScheduledCompletionNotification = false
        lastCompletionNotificationTime = nil
        scheduledNotificationCompletionTime = nil
    }
    
    func startTimer() {
        // If we already have a timer running, don't create a new one
        // This prevents timer jumps during brief state changes
        if timer != nil && timerModel.isTimerRunning {
            print("Timer already running, not restarting")
            return
        }
        
        let now = Date()
        print("Starting timer at \(now)")
        
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
            
        timerModel.isTimerRunning = true
        lastActiveTimestamp = now
        lastTimerFireTime = now
        timerModel.warningTriggered = false
        setCompletionWarningTriggered = false
        backgroundWarningTimes = []
        scheduledWarnings = []
        
        // Don't reset played warnings when just starting/resuming the timer
        // This ensures we don't play the same warnings again
        
        // Log when starting the timer for the first time
        if timerModel.currentSet == 1 && timerModel.currentMinutes == timerModel.minutes && timerModel.currentSeconds == timerModel.seconds {
            print("Timer entered into set-1, it is running \(timerModel.isCurrentIntensityLow ? "low" : "high") intensity phase now.")
        }
            
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentTime = Date()
            let timeSinceLastFire = currentTime.timeIntervalSince(self.lastTimerFireTime)
            
            // Enhanced timer firing compensation with more precise handling
            if timeSinceLastFire > 1.2 {  // Lowered threshold for more accurate compensation
                // Calculate exact number of seconds to catch up, including fractional part
                let exactExtraSeconds = timeSinceLastFire - 1.0
                let fullExtraSeconds = Int(exactExtraSeconds)
                let fractionalPart = exactExtraSeconds - Double(fullExtraSeconds)
                
                print("Timer fired after \(String(format: "%.3f", timeSinceLastFire)) seconds (adjusting for \(fullExtraSeconds) full seconds + \(String(format: "%.3f", fractionalPart)) fractional)")
                
                // Update multiple times if needed to catch up
                for _ in 0..<fullExtraSeconds {
                    self.updateTimer()
                }
                
                // For fractional parts over 0.7, add one more update
                // This helps with accuracy for brief app switches
                if fractionalPart > 0.7 {
                    print("Adding extra update for large fractional part: \(String(format: "%.3f", fractionalPart))")
                    self.updateTimer()
                }
            }
            
            self.lastTimerFireTime = currentTime
            self.updateTimer()
        }
        
        // Ensure timer runs in common run loop mode for better reliability
        if let activeTimer = timer {
            RunLoop.current.add(activeTimer, forMode: .common)
        }
        
        print("Timer started/resumed at \(now)")
    }
    
    func pauseTimer() {
        timerModel.isTimerRunning = false
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
        audioManager.stopSpeech()
        endBackgroundTask()
    }
    
    func stopTimer() {
        timerModel.isTimerRunning = false
        
        // Invalidate all timers
        timer?.invalidate()
        timer = nil
        
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        
        phaseTransitionTimer?.invalidate()
        phaseTransitionTimer = nil
        
        // Stop all audio
        stopWarningSound()
        audioManager.stopSpeech()
        
        // End background task and cancel notifications
        endBackgroundTask()
        cancelPendingNotifications()
        
        // Reset phase transition flag
        isPhaseTransitioning = false
        
        print("Timer stopped and all resources released")
    }
    
    func resetTimer() {
        stopTimer()
        initializeTimer()
        
        // Reset phase transition flag and timer
        isPhaseTransitioning = false
        phaseTransitionTimer?.invalidate()
        phaseTransitionTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func updateTimer() {
        checkAndPlayWarningSound()
        checkAndPlaySetCompletionWarning()
        
        if timerModel.currentSeconds > 0 {
            timerModel.currentSeconds -= 1
        } else if timerModel.currentMinutes > 0 {
            timerModel.currentMinutes -= 1
            timerModel.currentSeconds = 59
        } else {
            // Phase transition is about to occur - set flag to control UI animations
            isPhaseTransitioning = true
            
            // Schedule a timer to reset the phase transition flag after a short delay
            phaseTransitionTimer?.invalidate()
            phaseTransitionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                self?.isPhaseTransitioning = false
            }
            
            if timerModel.isCurrentIntensityLow {
                timerModel.lowIntensityCompleted = true
            } else {
                timerModel.highIntensityCompleted = true
            }
            
            // Check if the set is completed (both low and high phases done)
            if timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted {
                if timerModel.currentSet < timerModel.sets {
                    timerModel.currentSet += 1
                    timerModel.lowIntensityCompleted = false
                    timerModel.highIntensityCompleted = false
                    setCompletionWarningTriggered = false // Reset for the next set
                    
                    // Reset to the user's configured intensity preference for the new set
                    timerModel.isCurrentIntensityLow = timerModel.isLowIntensity
                    
                    // Reset minutes and seconds for the new set
                    timerModel.currentMinutes = timerModel.minutes
                    timerModel.currentSeconds = timerModel.seconds
                    timerModel.warningTriggered = false
                    
                    // Log when entering a new set
                    print("***ENTERED INTO SET-\(timerModel.currentSet): Running in \(timerModel.isCurrentIntensityLow ? "low" : "high") intensity phase now.***")
                    
                    // Return here to prevent the phase toggle logic below from executing
                    // This fixes the issue where a new set would immediately toggle phase
                    return
                } else {
                    completeTimer()
                    return
                }
            }
            
            timerModel.currentMinutes = timerModel.minutes
            timerModel.currentSeconds = timerModel.seconds
            
            // Store the previous intensity state before toggling
            let wasLowIntensity = timerModel.isCurrentIntensityLow
            timerModel.isCurrentIntensityLow.toggle()
            timerModel.warningTriggered = false
            
            // Log phase transition with set number
            print("***SET-\(timerModel.currentSet) PHASE TRNASITION: Now, timer running in \(timerModel.isCurrentIntensityLow ? "low" : "high") intensity phase.***")
        }
    }
    
    private func completeTimer() {
        stopTimer()
        timerModel.isTimerCompleted = true
        
        // Cancel any scheduled completion notifications first
        notificationService.cancelNotification(withIdentifier: "workoutComplete")
        hasScheduledCompletionNotification = false
        scheduledNotificationCompletionTime = nil
        
        // Check if speech is currently playing
        if audioManager.isSpeaking() {
            print("Speech is currently playing, delaying completion notification")
            
            // Wait for speech to complete before sending notification
            audioManager.speakText("", completion: { [weak self] in
                self?.sendCompletionNotification()
            })
        } else {
            // No speech playing, send notification immediately
            sendCompletionNotification()
        }
        
        // Provide haptic feedback if in foreground
        if UIApplication.shared.applicationState != .background {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
    // Separate method to send completion notification
    private func sendCompletionNotification() {
        // Only send notification if in background
        if UIApplication.shared.applicationState == .background {
            // Only send notification if we haven't sent one recently (within 10 seconds)
            let now = Date()
            
            // Check if we have a scheduled completion time and we're not yet at that time
            if let scheduledTime = scheduledNotificationCompletionTime, 
               now < scheduledTime {
                print("Skipping immediate completion notification - scheduled notification will fire at \(scheduledTime)")
                return
            }
            
            // Check if we've sent a notification recently
            if let lastTime = lastCompletionNotificationTime, 
               now.timeIntervalSince(lastTime) < 10.0 {
                print("Skipping duplicate completion notification - last one sent \(now.timeIntervalSince(lastTime)) seconds ago")
                return
            }
            
            // Send the notification
            notificationService.sendLocalNotification(
                title: "Workout Complete!",
                body: "You've completed all \(timerModel.sets) sets. Great job!"
            )
            lastCompletionNotificationTime = now
            print("Sent workout completion notification at \(now)")
        }
    }
    
    // MARK: - Audio Methods
    
    private func prepareWarningSound() {
        warningSoundDuration = audioManager.prepareSound(named: "notification", withExtension: "mp3")
        print("Warning sound duration: \(warningSoundDuration) seconds")
    }
    
    private func playWarningSound() -> Bool {
        // Only set the flag and play if not already playing
        if !audioManager.isPlaying() && !audioManager.isSpeaking() {
            timerModel.warningTriggered = true
            
            // Play the sound using AudioManager
            let success = audioManager.playSound()
            
            if success {
                print("Warning sound played for phase transition in set \(timerModel.currentSet)")
                return true
            } else {
                print("Failed to play warning sound for phase transition in set \(timerModel.currentSet)")
                return false
            }
        }
        
        // Return false if audio is already playing
        return false
    }
    
    private func stopWarningSound() {
        audioManager.stopSound()
        timerModel.warningTriggered = false
    }
    
    private func checkAndPlayWarningSound() {
        // If warning already triggered, speech is playing, or timer completed, do nothing
        if timerModel.warningTriggered || audioManager.isSpeaking() || timerModel.isTimerCompleted {
            return
        }
        
        // Calculate remaining time in current phase
        let remainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // If remaining time equals our warning threshold, play the sound
        if remainingSeconds == warningSoundDuration {
            // Only play the warning sound if this is not the last phase of the set
            // (because for the last phase, we'll play the speech announcement instead)
            let isLastPhaseOfSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                                  (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
            
            if !isLastPhaseOfSet {
                playWarningSound()
            }
        }
    }
    
    // Method to check and play set completion warning
    private func checkAndPlaySetCompletionWarning() {
        // If warning already triggered or timer completed, do nothing
        if setCompletionWarningTriggered || timerModel.isTimerCompleted {
            return
        }
        
        // Calculate remaining time in current phase
        let remainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // Determine if this is the final phase of the set
        let isLastPhaseOfSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                              (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
        
        // If this is the last phase of the set and we're at the warning threshold
        if isLastPhaseOfSet && remainingSeconds == setCompletionWarningSeconds {
            setCompletionWarningTriggered = true
            
            let now = Date()
            let currentSet = timerModel.currentSet
            
            // Check if we've played this warning recently (within 10 seconds)
            if let lastPlayedTime = playedSetCompletionWarningsWithTime[currentSet],
               now.timeIntervalSince(lastPlayedTime) < 10.0 {
                print("Skipping duplicate set completion announcement for set \(currentSet) - played \(now.timeIntervalSince(lastPlayedTime)) seconds ago")
                return
            }
            
            // Special handling for the final set - always play the warning
            let isFinalSet = currentSet == timerModel.sets
            
            // If this is the final set, cancel any scheduled completion notifications
            // to prevent them from firing before the speech warning completes
            if isFinalSet {
                print("Final set completion warning about to play - canceling scheduled completion notifications")
                notificationService.cancelNotification(withIdentifier: "workoutComplete")
                hasScheduledCompletionNotification = false
                scheduledNotificationCompletionTime = nil
            }
            
            // Check if we've already played this set's completion warning
            if isFinalSet || !playedSetCompletionWarnings.contains(currentSet) {
                // Add to played warnings set
                playedSetCompletionWarnings.insert(currentSet)
                playedSetCompletionWarningsWithTime[currentSet] = now
                
                // Print predictive log to help with debugging
                if currentSet < timerModel.sets {
                    // Next set will start with the user's configured intensity preference
                    print("***PREDICTING TRANSITION TO SET-\(currentSet + 1): Will be running in \(timerModel.isLowIntensity ? "low" : "high") intensity phase in \(setCompletionWarningSeconds) seconds***")
                } else {
                    // Final set completion
                    print("***PREDICTING WORKOUT COMPLETION in \(setCompletionWarningSeconds) seconds***")
                }
                
                // Speak the set completion warning
                let setCompletionText = "Set \(currentSet) completing in 3, 2, 1, 0"
                
                // For the final set, add a completion handler to ensure notifications are sent after speech
                if isFinalSet {
                    let _ = audioManager.speakText(setCompletionText, rate: 0.5) {
                        // This will be called when speech completes
                        print("Final set completion announcement finished")
                    }
                } else {
                    // For non-final sets, no completion handler needed
                    let _ = audioManager.speakText(setCompletionText, rate: 0.5)
                }
                
                print("Playing set completion announcement for set \(currentSet) at \(now)")
            } else {
                print("Skipping duplicate set completion announcement for set \(currentSet)")
            }
        }
    }
    
    // MARK: - Background Task Management
    
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        let now = Date()
        
        switch newPhase {
            case .active:
                print("App became active at \(now)")
                // App came to foreground
                isInBackgroundMode = false
                hasScheduledCompletionNotification = false
                scheduledNotificationCompletionTime = nil
                
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    // Calculate how long the app was in background/inactive with precise timing
                    let timeSinceStateChange = now.timeIntervalSince(lastStateChangeTime)
                    print("Time since state change: \(String(format: "%.3f", timeSinceStateChange)) seconds")
                    
                    // Log current timer state for debugging
                    print("Current timer state - Set: \(timerModel.currentSet)/\(timerModel.sets), Time: \(timerModel.currentMinutes):\(timerModel.currentSeconds), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High")")
                    
                    if timeSinceStateChange < minimumBackgroundTime {
                        // For very brief app switches, preserve the timer completely
                        print("Brief app switch (\(String(format: "%.3f", timeSinceStateChange))s), preserving timer state")
                        
                        // If the timer was somehow invalidated, restart it without adjustment
                        if timer == nil {
                            print("Timer was invalidated during brief app switch, restarting without adjustment")
                            startTimer()
                        } else {
                            // Update the lastTimerFireTime to prevent jumps on the next timer fire
                            // Calculate exact time since last fire to improve accuracy
                            let timeSinceLastFire = now.timeIntervalSince(lastTimerFireTime)
                            
                            // If it's been more than 1 second since the last fire, we might need to update
                            if timeSinceLastFire > 1.0 {
                                let secondsToUpdate = Int(timeSinceLastFire)
                                print("Time since last timer fire: \(String(format: "%.3f", timeSinceLastFire))s, updating \(secondsToUpdate) seconds")
                                
                                // Update the timer for each second that has passed
                                for _ in 0..<secondsToUpdate {
                                    updateTimer()
                                }
                            }
                            
                            lastTimerFireTime = now
                            print("Existing timer preserved, updated lastTimerFireTime and synchronized timer state")
                        }
                    } else {
                        // For longer background durations, perform full adjustment
                        print("Longer duration away (\(String(format: "%.3f", timeSinceStateChange))s), performing full adjustment")
                        
                        // Properly clean up background resources
                        cleanupBackgroundResources()
                        
                        adjustTimerForBackgroundTime()
                        cancelPendingNotifications()
                        
                        // Restart the timer if it's still supposed to be running
                        if !timerModel.isTimerCompleted && timerModel.currentSet <= timerModel.sets {
                            startTimer()
                        }
                    }
                }
                
                // Ensure audio session is active when returning to foreground
                audioManager.setupAudioSession()
                
                // End background task if it exists
                endBackgroundTask()
                
            case .background:
                lastStateChangeTime = now
                print("App entered background at \(now)")
                isInBackgroundMode = true
                        
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    beginBackgroundTask()
                    
                    // Log current timer state before scheduling warnings
                    print("Entering background - Current timer state - Set: \(timerModel.currentSet)/\(timerModel.sets), Time: \(timerModel.currentMinutes):\(timerModel.currentSeconds), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High")")
                    
                    // Schedule warnings based on current timer state.
                    // Note: The timer continues to advance internally while in background,
                    // so warnings will be played based on the actual timer state at the time
                    // they're triggered, not necessarily what was scheduled here.
                    scheduleBackgroundWarnings()
                    
                    scheduleCompletionNotification()
                }
                        
            case .inactive:
                print("App became inactive at \(now)")
                lastStateChangeTime = now
                
                // Log current timer state when going inactive
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    print("App becoming inactive - Current timer state - Set: \(timerModel.currentSet)/\(timerModel.sets), Time: \(timerModel.currentMinutes):\(timerModel.currentSeconds), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High")")
                }
                
            @unknown default:
                print("Unknown scene phase change at \(now)")
                break
        }
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTaskStartTime = Date()
        
        // Create expiration handler that attempts to renew the task
        backgroundTaskExpirationHandler = { [weak self] in
            print("Background task expiring, attempting renewal")
            self?.renewBackgroundTask()
        }
        
        // Check if we're in low power mode and adjust behavior accordingly
        let inLowPowerMode = isLowPowerMode
        if inLowPowerMode {
            print("Device is in low power mode - optimizing background operation")
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("Background task expired")
            self?.backgroundTaskExpirationHandler?()
            self?.endBackgroundTask()
        }
        
        print("Started background task with ID: \(backgroundTaskID.rawValue)")
        
        // Start audio session keep-alive
        audioManager.startAudioSessionKeepAlive()
        
        // Set up renewal timer (attempt renewal every 25 seconds)
        backgroundTaskRenewalTimer = Timer.scheduledTimer(withTimeInterval: 25.0, repeats: true) { [weak self] _ in
            self?.renewBackgroundTask()
        }
        RunLoop.current.add(backgroundTaskRenewalTimer!, forMode: .common)
        
        // Activate audio session for background
        activateAudioSessionForBackground()
        
        setupBackgroundAudioRefresh()
    }
    
    // New method to renew background task
    private func renewBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        
        // End current task
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        
        // Begin new task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("Renewed background task expired")
            self?.backgroundTaskExpirationHandler?()
            self?.endBackgroundTask()
        }
        
        print("Renewed background task with ID: \(backgroundTaskID.rawValue)")
        
        // Check audio session health and refresh if needed
        if !audioManager.isAudioSessionHealthy() {
            print("Audio session unhealthy during renewal, refreshing")
            activateAudioSessionForBackground()
        }
    }
    
    // New method to activate audio session specifically for background
    private func activateAudioSessionForBackground() {
        // Only activate audio session if we have upcoming warnings or we're close to completion
        let totalRemainingTime = calculateTotalRemainingTime()
        let isNearCompletion = totalRemainingTime < 60 // Within a minute of completion
        
        // Calculate time to next warning
        let now = Date()
        var hasUpcomingWarnings = false
        
        if !scheduledWarnings.isEmpty {
            let sortedWarnings = scheduledWarnings.sorted { $0.time < $1.time }
            if let nextWarning = sortedWarnings.first {
                let timeToNextWarning = nextWarning.time.timeIntervalSince(now)
                hasUpcomingWarnings = timeToNextWarning < 30.0 // Warning within 30 seconds
            }
        }
        
        // Always activate for the first minute of background operation
        let isInitialBackgroundPeriod = backgroundTaskStartTime != nil && 
                                      now.timeIntervalSince(backgroundTaskStartTime!) < 60
        
        // In low power mode, only activate audio session when absolutely necessary
        let inLowPowerMode = isLowPowerMode
        
        if isInitialBackgroundPeriod || hasUpcomingWarnings || isNearCompletion || !inLowPowerMode {
            audioManager.setupAudioSession()
            print("Audio session activated for background task")
        } else {
            print("Delaying audio session activation to save battery - no imminent warnings or completion")
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            print("Ending background task with ID: \(backgroundTaskID.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        // Clean up renewal timer
        backgroundTaskRenewalTimer?.invalidate()
        backgroundTaskRenewalTimer = nil
        backgroundTaskStartTime = nil
        backgroundTaskExpirationHandler = nil
        
        // Stop audio session keep-alive
        audioManager.stopAudioSessionKeepAlive()
    }
    
    private func cleanupBackgroundResources() {
        // Invalidate and nil all background timers
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        
        backgroundTaskRenewalTimer?.invalidate()
        backgroundTaskRenewalTimer = nil
        
        // Clear warning arrays
        backgroundWarningTimes = []
        scheduledWarnings = []
        
        // Release any other resources that might consume battery
        if audioManager.isAnyAudioPlaying() {
            audioManager.stopSound()
            audioManager.stopSpeech()
        }
        
        // Reset background task tracking
        backgroundTaskStartTime = nil
        backgroundTaskExpirationHandler = nil
        
        print("Background resources cleaned up")
    }
    
    /// Schedules audio warnings to be played while the app is in the background.
    ///
    /// This method calculates when warnings should be played based on the current timer state
    /// and future phases. It schedules two types of warnings:
    /// - Phase transition warnings: Played before transitioning between low and high intensity
    /// - Set completion warnings: Played before completing a set
    ///
    /// Important: While this method schedules warnings with specific set numbers, the actual
    /// set number announced at playback time is determined by the current timer state at that moment.
    /// This ensures that if the timer advances while in background, the correct set number is announced.
    private func scheduleBackgroundWarnings() {
        backgroundWarningTimes = []
        scheduledWarnings = []
        backgroundCheckTimer?.invalidate()
        
        let now = Date()
        
        let currentRemainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        let isCurrentPhaseLastInSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                                     (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
        
        if currentRemainingSeconds > warningSoundDuration {
            if !isCurrentPhaseLastInSet {
                let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
                scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
                print("Scheduled phase transition for current set-\(timerModel.currentSet), warning at \(warningTime)")
            }
        }
        
        if isCurrentPhaseLastInSet && currentRemainingSeconds > setCompletionWarningSeconds {
            let setCompletionWarningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - setCompletionWarningSeconds))
            scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: timerModel.currentSet)))
            print("Scheduled set completion for current set-\(timerModel.currentSet), warning at \(setCompletionWarningTime)")
        }
        
        var timeOffset = TimeInterval(currentRemainingSeconds)
        
        var phaseSequence: [(isLow: Bool, isLastInSet: Bool, setNumber: Int)] = []
        
        let currentPhaseIsLow = timerModel.isCurrentIntensityLow
        let currentSetNumber = timerModel.currentSet
        
        if !isCurrentPhaseLastInSet {
            phaseSequence.append((isLow: !currentPhaseIsLow, isLastInSet: true, setNumber: currentSetNumber))
        }
        
        // Add two phases for each remaining set (low and high)
        for setIndex in currentSetNumber..<timerModel.sets {
            if setIndex > currentSetNumber || (setIndex == currentSetNumber && isCurrentPhaseLastInSet) {
                // Use the correct set number for scheduling (the actual set number, not +1)
                let targetSetNumber = setIndex + 1
                if targetSetNumber <= timerModel.sets {
                    // First phase of the set should use the user's configured intensity preference
                    phaseSequence.append((isLow: timerModel.isLowIntensity, isLastInSet: false, setNumber: targetSetNumber))
                    // Second phase of the set should use the opposite intensity
                    phaseSequence.append((isLow: !timerModel.isLowIntensity, isLastInSet: true, setNumber: targetSetNumber))
                    
                    print("Scheduled phases for set \(targetSetNumber): \(timerModel.isLowIntensity ? "Low" : "High") followed by \(!timerModel.isLowIntensity ? "Low" : "High")")
                }
            }
        }
                
        // Schedule warnings for all future phases
        for (_, phase) in phaseSequence.enumerated() {
            timeOffset += TimeInterval(timerModel.totalSeconds)
            
            if !phase.isLastInSet && timeOffset > TimeInterval(warningSoundDuration) {
                let warningTime = now.addingTimeInterval(timeOffset - TimeInterval(warningSoundDuration))
                scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
                print("Scheduled phase transition warning for set-\(phase.setNumber) at \(warningTime)")
            }
            
            if phase.isLastInSet && timeOffset > TimeInterval(setCompletionWarningSeconds) {
                let setCompletionWarningTime = now.addingTimeInterval(timeOffset - TimeInterval(setCompletionWarningSeconds))
                scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: phase.setNumber)))
                print("Scheduled set completion warning for set-\(phase.setNumber) at \(setCompletionWarningTime)")
            }
        }
        
        backgroundWarningTimes = scheduledWarnings.map { $0.time }
        
        print("Scheduled \(scheduledWarnings.count) warnings:")
        for (index, warning) in scheduledWarnings.enumerated() {
            let timeInterval = warning.time.timeIntervalSince(now)
            let typeString: String
            switch warning.type {
            case .phaseTransition:
                typeString = "Phase Transition"
            case .setCompletion(let setNumber):
                typeString = "Set \(setNumber) Completion"
            }
            print("Warning \(index + 1): \(typeString) in \(timeInterval) seconds")
        }
        
        backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkBackgroundWarnings()
        }
        
        // Make sure the timer runs even when app is in background
        if let timer = backgroundCheckTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    /// Checks if any scheduled warnings should be played and triggers them if appropriate.
    ///
    /// This method is called periodically by the backgroundCheckTimer to check if any
    /// scheduled warnings should be played. When a warning time is reached:
    /// - For phase transitions: A sound is played
    /// - For set completions: A speech announcement is made using the CURRENT set number
    ///   from the timer model, not necessarily the set number that was stored when the
    ///   warning was scheduled. This ensures the announcement matches the actual timer state.
    private func checkBackgroundWarnings() {
        guard !scheduledWarnings.isEmpty else { return }
        
        if audioManager.isAnyAudioPlaying() {
            return
        }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        for (index, warning) in scheduledWarnings.enumerated() {
            if now >= warning.time || now.timeIntervalSince(warning.time) > -0.5 {
                // Ensure audio session is active before playing
                if !audioManager.isAudioSessionHealthy() {
                    print("Refreshing audio session before playing warning")
                    audioManager.setupAudioSession()
                }
                
                // Try to play the warning
                var playbackSucceeded = false
                
                switch warning.type {
                case .phaseTransition:
                    // Play warning sound with retry
                    for attempt in 1...3 {
                        if playWarningSound() {
                            playbackSucceeded = true
                            print("Phase transition warning played successfully on attempt \(attempt)")
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.2)
                        // Try to refresh audio session before retry
                        audioManager.setupAudioSession()
                    }
                    
                    if playbackSucceeded {
                        print("Playing phase transition warning sound at \(now)")
                    } else {
                        print("Failed to play phase transition warning after multiple attempts")
                    }
                    
                case .setCompletion(let setNumber):
                    // Use current set number for accuracy
                    let actualSetNumber = timerModel.currentSet
                    
                    // Log if there's a mismatch between scheduled and actual set numbers
                    if setNumber != actualSetNumber {
                        print("Note: Set completion was scheduled for set \(setNumber) but playing for current set \(actualSetNumber)")
                    }
                    
                    // Check for duplicates
                    if let lastPlayedTime = playedSetCompletionWarningsWithTime[actualSetNumber],
                       now.timeIntervalSince(lastPlayedTime) < 10.0 {
                        print("Skipping duplicate set completion announcement for set \(actualSetNumber) - played \(now.timeIntervalSince(lastPlayedTime)) seconds ago")
                        playbackSucceeded = true
                    } else {
                        let isFinalSet = actualSetNumber == timerModel.sets
                        
                        // If this is the final set, cancel any scheduled completion notifications
                        // to prevent them from firing before the speech warning completes
                        if isFinalSet {
                            print("Final set completion warning about to play in background - canceling scheduled completion notifications")
                            notificationService.cancelNotification(withIdentifier: "workoutComplete")
                            hasScheduledCompletionNotification = false
                            scheduledNotificationCompletionTime = nil
                        }
                        
                        // Only play if we haven't already played this set's completion warning or it's the final set
                        if isFinalSet || !playedSetCompletionWarnings.contains(actualSetNumber) {
                            // Play speech with retry
                            for attempt in 1...3 {
                                let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
                                
                                // For the final set, add a completion handler
                                if isFinalSet {
                                    if audioManager.speakText(setCompletionText, rate: 0.3, completion: { [weak self] in
                                        print("Final set completion announcement finished")
                                    }) {
                                        // Print predictive log to help with debugging
                                        if actualSetNumber < timerModel.sets {
                                            // Next set will start with the user's configured intensity preference
                                            print("***PREDICTING TRANSITION TO SET-\(actualSetNumber + 1): Will be running in \(timerModel.isLowIntensity ? "low" : "high") intensity phase in \(setCompletionWarningSeconds) seconds***")
                                        } else {
                                            // Final set completion
                                            print("***PREDICTING WORKOUT COMPLETION in \(setCompletionWarningSeconds) seconds***")
                                        }
                                        
                                        playedSetCompletionWarnings.insert(actualSetNumber)
                                        playedSetCompletionWarningsWithTime[actualSetNumber] = now
                                        playbackSucceeded = true
                                        print("Set completion announcement played successfully on attempt \(attempt)")
                                        print("Playing set completion announcement for set \(actualSetNumber) at \(now) (scheduled as set \(setNumber))")
                                        break
                                    }
                                } else {
                                    // For non-final sets, no completion handler needed
                                    if audioManager.speakText(setCompletionText, rate: 0.3) {
                                        // Print predictive log to help with debugging
                                        if actualSetNumber < timerModel.sets {
                                            // Next set will start with the user's configured intensity preference
                                            print("***PREDICTING TRANSITION TO SET-\(actualSetNumber + 1): Will be running in \(timerModel.isLowIntensity ? "low" : "high") intensity phase in \(setCompletionWarningSeconds) seconds***")
                                        }
                                        
                                        playedSetCompletionWarnings.insert(actualSetNumber)
                                        playedSetCompletionWarningsWithTime[actualSetNumber] = now
                                        playbackSucceeded = true
                                        print("Set completion announcement played successfully on attempt \(attempt)")
                                        print("Playing set completion announcement for set \(actualSetNumber) at \(now) (scheduled as set \(setNumber))")
                                        break
                                    }
                                }
                                
                                Thread.sleep(forTimeInterval: 0.2)
                                // Try to refresh audio session before retry
                                audioManager.setupAudioSession()
                            }
                            
                            if !playbackSucceeded {
                                print("Failed to play set completion announcement after multiple attempts")
                            }
                        } else {
                            print("Skipping duplicate set completion announcement for set \(actualSetNumber) at \(now)")
                            playbackSucceeded = true
                        }
                    }
                }
                
                // Only remove the warning if playback succeeded or we've tried multiple times
                if playbackSucceeded {
                    triggeredIndices.append(index)
                }
                
                // Only process one warning at a time
                break
            }
        }
        
        // Remove triggered warnings (in reverse order to avoid index issues)
        for index in triggeredIndices.sorted(by: >) {
            if index < scheduledWarnings.count {
                scheduledWarnings.remove(at: index)
                
                // Also remove from backgroundWarningTimes for compatibility
                if index < backgroundWarningTimes.count {
                    backgroundWarningTimes.remove(at: index)
                }
            }
        }
        
        // If all warnings have been played, stop the check timer
        if scheduledWarnings.isEmpty && backgroundCheckTimer != nil {
            print("All warnings played, stopping background check timer")
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
        }
    }
    
    private func adjustTimerForBackgroundTime() {
        let now = Date()
        // Use more precise time calculation with fractional seconds
        let elapsedTimeExact = now.timeIntervalSince(lastActiveTimestamp)
        let elapsedTime = Int(elapsedTimeExact)
        let fractionalPart = elapsedTimeExact - Double(elapsedTime)
        
        // Don't adjust if elapsed time is too small or suspiciously large
        guard elapsedTime >= Int(minimumBackgroundTime) && elapsedTime < 3600 else {
            print("Skipping timer adjustment - elapsed time: \(String(format: "%.3f", elapsedTimeExact)) seconds")
            lastActiveTimestamp = now
            return
        }
            
        print("Adjusting timer for background time: \(String(format: "%.3f", elapsedTimeExact)) seconds (\(elapsedTime) seconds + \(String(format: "%.3f", fractionalPart)) fractional)")
        
        var remainingTimeToProcess = elapsedTime
        var currentSetNumber = timerModel.currentSet
        var currentMin = timerModel.currentMinutes
        var currentSec = timerModel.currentSeconds
        var currentIntens = timerModel.isCurrentIntensityLow
        var lowPhaseCompleted = timerModel.lowIntensityCompleted
        var highPhaseCompleted = timerModel.highIntensityCompleted
        
        // Log initial state for debugging
        print("Initial state - Set: \(currentSetNumber)/\(timerModel.sets), Time: \(currentMin):\(currentSec), Phase: \(currentIntens ? "Low" : "High"), Low completed: \(lowPhaseCompleted), High completed: \(highPhaseCompleted)")
        
        while remainingTimeToProcess > 0 && currentSetNumber <= timerModel.sets {
            let currentIntervalRemaining = currentMin * 60 + currentSec
            
            if remainingTimeToProcess >= currentIntervalRemaining {
                // This interval is completed
                remainingTimeToProcess -= currentIntervalRemaining
                
                if currentIntens {
                    lowPhaseCompleted = true
                    print("Low intensity phase completed for set \(currentSetNumber)")
                } else {
                    highPhaseCompleted = true
                    print("High intensity phase completed for set \(currentSetNumber)")
                }
                
                if lowPhaseCompleted && highPhaseCompleted {
                    if currentSetNumber < timerModel.sets {
                        currentSetNumber += 1
                        lowPhaseCompleted = false
                        highPhaseCompleted = false
                        // Reset to the user's configured intensity preference for the new set
                        currentIntens = timerModel.isLowIntensity
                        
                        // Reset minutes and seconds for the new set
                        currentMin = timerModel.minutes
                        currentSec = timerModel.seconds
                        
                        print("Set \(currentSetNumber-1) completed, moving to set \(currentSetNumber) with \(currentIntens ? "low" : "high") intensity")
                        
                        // Skip to the next iteration to avoid the phase toggle logic below
                        continue
                    } else {
                        currentSetNumber = timerModel.sets // This ensures we know it's completed
                        currentMin = 0
                        currentSec = 0
                        remainingTimeToProcess = 0 // Stop processing
                        print("All sets completed")
                        break
                    }
                } else {
                    // Only toggle intensity if we're not starting a new set
                    currentIntens.toggle()
                    print("Phase changed to \(currentIntens ? "Low" : "High") intensity")
                    
                    // Reset minutes and seconds for the new phase
                    currentMin = timerModel.minutes
                    currentSec = timerModel.seconds
                }
                
            } else {
                // Partial completion of current interval
                let newRemainingSeconds = currentIntervalRemaining - remainingTimeToProcess
                currentMin = newRemainingSeconds / 60
                currentSec = newRemainingSeconds % 60
                print("Partial completion - \(remainingTimeToProcess) seconds processed, \(newRemainingSeconds) seconds remaining in current interval")
                remainingTimeToProcess = 0
            }
        }
        
        // Account for fractional seconds by potentially decrementing one more second
        // This improves accuracy for brief background periods
        if fractionalPart > 0.7 && currentSec > 0 {
            print("Adjusting for large fractional part (\(String(format: "%.3f", fractionalPart))): decrementing one more second")
            currentSec -= 1
            if currentSec < 0 {
                if currentMin > 0 {
                    currentMin -= 1
                    currentSec = 59
                } else {
                    currentSec = 0
                }
            }
        }
        
        // Update the model with calculated values
        timerModel.currentSet = currentSetNumber
        timerModel.currentMinutes = max(0, currentMin)
        timerModel.currentSeconds = max(0, currentSec)
        timerModel.isCurrentIntensityLow = currentIntens
        timerModel.lowIntensityCompleted = lowPhaseCompleted
        timerModel.highIntensityCompleted = highPhaseCompleted
        timerModel.warningTriggered = false // Reset warning flag after background time
        setCompletionWarningTriggered = false // Reset set completion warning flag
            
        // If we've completed all sets
        if timerModel.currentSet > timerModel.sets || (timerModel.currentSet == timerModel.sets && timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted) {
            timerModel.isTimerCompleted = true
            timerModel.isTimerRunning = false
            timerModel.currentMinutes = 0
            timerModel.currentSeconds = 0
            print("Timer marked as completed")
        }
        
        lastActiveTimestamp = now
        print("Timer adjusted to: \(timerModel.currentMinutes):\(timerModel.currentSeconds), Set \(timerModel.currentSet)/\(timerModel.sets), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High"), Low completed: \(timerModel.lowIntensityCompleted), High completed: \(timerModel.highIntensityCompleted)")
    }
    
    private func setupBackgroundAudioRefresh() {
        // Clean up any existing timer
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
        
        // Calculate optimal refresh interval based on workout duration
        let totalDuration = timerModel.totalWorkoutDuration
        
        // For very long workouts (>10 minutes), use adaptive refresh strategy
        let baseRefreshInterval: TimeInterval
        if totalDuration > 600 { // 10 minutes
           baseRefreshInterval = 15.0 // 15 seconds for long workouts
        } else {
           baseRefreshInterval = 10.0 // 10 seconds for shorter workouts
        }
        
        // Calculate time to next warning
        let now = Date()
        var timeToNextWarning: TimeInterval = 60.0 // Default to 60 seconds if no warnings
        
        if !scheduledWarnings.isEmpty {
            let sortedWarnings = scheduledWarnings.sorted { $0.time < $1.time }
            if let nextWarning = sortedWarnings.first {
                timeToNextWarning = nextWarning.time.timeIntervalSince(now)
            }
        }
        
        // Use more frequent refreshes when warnings are coming soon
        let refreshInterval: TimeInterval
        if timeToNextWarning <= 30.0 {
            // More frequent refreshes when warnings are coming soon (within 30 seconds)
            refreshInterval = min(5.0, baseRefreshInterval) // Even more frequent for imminent warnings
            print("Using high-frequency audio refresh interval (\(refreshInterval)s) due to imminent warnings")
        } else if timeToNextWarning <= 120.0 {
            // Medium frequency for warnings within 2 minutes
            refreshInterval = min(10.0, baseRefreshInterval)
            print("Using medium audio refresh interval (\(refreshInterval)s)")
        } else {
            // Less frequent refreshes for distant warnings to save battery
            refreshInterval = baseRefreshInterval
            print("Using optimized audio refresh interval (\(refreshInterval)s)")
        }
        
        // Create a timer that periodically checks if warnings need to be played
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timerModel.isTimerRunning && !self.timerModel.isTimerCompleted {
                // Check if we need to refresh the audio session
                if !self.audioManager.isAudioSessionHealthy() {
                    print("Audio session unhealthy, refreshing during background check")
                    self.activateAudioSessionForBackground()
                }
                
                // Log current timer state for debugging extended background sessions
                print("Background refresh - Current timer state - Set: \(self.timerModel.currentSet)/\(self.timerModel.sets), Time: \(self.timerModel.currentMinutes):\(self.timerModel.currentSeconds), Phase: \(self.timerModel.isCurrentIntensityLow ? "Low" : "High")")
                
                // Check if any warnings should be played soon
                let now = Date()
                if !self.scheduledWarnings.isEmpty {
                    let soonWarnings = self.scheduledWarnings.filter { now.timeIntervalSince($0.time) > -10 && now.timeIntervalSince($0.time) < 10 }
                    if !soonWarnings.isEmpty {
                        print("Upcoming warnings in next 10 seconds: \(soonWarnings.count)")
                    }
                }
                
                // Check if any warnings should be played
                self.checkBackgroundWarnings()
            }
        }
        
        // Ensure timer runs in background
        if let timer = backgroundRefreshTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    // MARK: - Notification Methods
    
    private func scheduleCompletionNotification() {
        // If we've already scheduled a completion notification, don't schedule another one
        if hasScheduledCompletionNotification {
            print("Completion notification already scheduled, skipping")
            return
        }
        
        cancelPendingNotifications()
        
        var totalRemainingSeconds = calculateTotalRemainingTime()
        
        // For very short intervals, use a larger buffer
        let isShortInterval = timerModel.totalSeconds <= 15
        
        // Add a buffer to prevent premature notifications
        // Use a larger buffer (8 seconds) for short intervals, otherwise use 5 seconds
        let bufferSeconds = isShortInterval ? 8 : 5
        totalRemainingSeconds += bufferSeconds
        
        // Schedule final completion notification
        if totalRemainingSeconds > 0 {
            // Calculate and store the scheduled completion time
            let scheduledTime = Date().addingTimeInterval(TimeInterval(totalRemainingSeconds))
            scheduledNotificationCompletionTime = scheduledTime
            
            notificationService.scheduleNotification(
                title: "Workout Complete!",
                body: "You've completed all \(timerModel.sets) sets. Great job!",
                timeInterval: TimeInterval(totalRemainingSeconds),
                identifier: "workoutComplete"
            )
            hasScheduledCompletionNotification = true
            print("Scheduling completion notification in \(totalRemainingSeconds) seconds (at \(scheduledTime))")
        }
    }
    
    private func calculateTotalRemainingTime() -> Int {
        let currentPhaseTimeRemaining = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        var totalRemainingSeconds = currentPhaseTimeRemaining
        
        var phasesRemaining = 0
        
        let currentSet = timerModel.currentSet
        let isLowPhase = timerModel.isCurrentIntensityLow
        let lowCompleted = timerModel.lowIntensityCompleted
        let highCompleted = timerModel.highIntensityCompleted
        
        if isLowPhase && !lowCompleted && !highCompleted {
            phasesRemaining += 1
        } else if !isLowPhase && lowCompleted && !highCompleted {
            phasesRemaining += 0
        } else if isLowPhase && lowCompleted && !highCompleted {
            phasesRemaining += 0
        } else if !isLowPhase && !lowCompleted && !highCompleted {
            phasesRemaining += 1
        }
        
        // Add time for remaining phases in current set
        totalRemainingSeconds += phasesRemaining * timerModel.totalSeconds
        
        // Add time for remaining full sets
        let completeSetsRemaining = timerModel.sets - currentSet
        if completeSetsRemaining > 0 {
            // Each remaining set has two phases (low and high intensity)
            totalRemainingSeconds += completeSetsRemaining * timerModel.totalSeconds * 2
        }
        
        // For very short intervals (10 seconds or less), add a small additional buffer
        // This helps prevent premature notifications
        if timerModel.totalSeconds <= 10 {
            // Add 1 second per remaining phase/set to account for timing variations
            let totalPhasesRemaining = phasesRemaining + (completeSetsRemaining * 2)
            totalRemainingSeconds += totalPhasesRemaining
        }
        
        print("Calculated total remaining time: \(totalRemainingSeconds) seconds")
        print("Current set: \(currentSet)/\(timerModel.sets), Phase: \(isLowPhase ? "Low" : "High"), Low completed: \(lowCompleted), High completed: \(highCompleted)")
        
        return totalRemainingSeconds
    }
    
    private func cancelPendingNotifications() {
        notificationService.cancelAllNotifications()
        hasScheduledCompletionNotification = false
        scheduledNotificationCompletionTime = nil
        print("Cancelled all pending notifications")
    }
}
