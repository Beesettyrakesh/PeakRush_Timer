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
    
    private var timer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lastActiveTimestamp: Date = Date()
    private var backgroundWarningTimes: [Date] = []
    private var backgroundCheckTimer: Timer?
    private var warningSoundDuration: Int = 0
    private var lastStateChangeTime: Date = Date()
    private var minimumBackgroundTime: TimeInterval = 3.0
    private var lastTimerFireTime: Date = Date()
    
    private var setCompletionWarningTriggered = false
    private var setCompletionWarningSeconds = 4
    
    private var playedSetCompletionWarnings: Set<Int> = []
    private var playedSetCompletionWarningsWithTime: [Int: Date] = [:]
    private var isInBackgroundMode = false
    private var hasScheduledCompletionNotification = false
    private var lastCompletionNotificationTime: Date? = nil
    private var scheduledNotificationCompletionTime: Date? = nil
    
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
    
    var circleColor: LinearGradient {
        if !timerModel.isTimerRunning && !timerModel.isTimerCompleted {
            return LinearGradient(
                colors: [.gray, .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if timerModel.isTimerCompleted {
            return LinearGradient(
                colors: [.blue, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            if timerModel.isCurrentIntensityLow {
                return LinearGradient(
                    colors: [.green, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [.red, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
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
            
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentTime = Date()
            let timeSinceLastFire = currentTime.timeIntervalSince(self.lastTimerFireTime)
            
            // If more than 1.5 seconds have passed since the last fire, 
            // adjust for the extra time to prevent jumps
            if timeSinceLastFire > 1.5 {
                let extraSeconds = Int(timeSinceLastFire) - 1
                print("Timer fired after \(timeSinceLastFire) seconds (adjusting for \(extraSeconds) extra seconds)")
                
                // Update multiple times if needed to catch up
                for _ in 0..<extraSeconds {
                    self.updateTimer()
                }
            }
            
            self.lastTimerFireTime = currentTime
            self.updateTimer()
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
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
        audioManager.stopSpeech()
        endBackgroundTask()
        cancelPendingNotifications()
    }
    
    func resetTimer() {
        stopTimer()
        initializeTimer()
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
                } else {
                    completeTimer()
                    return
                }
            }
            
            timerModel.currentMinutes = timerModel.minutes
            timerModel.currentSeconds = timerModel.seconds
            timerModel.isCurrentIntensityLow.toggle()
            timerModel.warningTriggered = false
        }
    }
    
    private func completeTimer() {
        stopTimer()
        timerModel.isTimerCompleted = true
        
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
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
    // MARK: - Audio Methods
    
    private func prepareWarningSound() {
        warningSoundDuration = audioManager.prepareSound(named: "notification", withExtension: "mp3")
        print("Warning sound duration: \(warningSoundDuration) seconds")
    }
    
    private func playWarningSound() {
        // Only set the flag and play if not already playing
        if !audioManager.isPlaying() && !audioManager.isSpeaking() {
            timerModel.warningTriggered = true
            
            // Play the sound using AudioManager
            let success = audioManager.playSound()
            
            if success {
                print("Warning sound played for phase transition in set \(timerModel.currentSet)")
            } else {
                print("Failed to play warning sound for phase transition in set \(timerModel.currentSet)")
            }
        }
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
            
            // Check if we've already played this set's completion warning
            if isFinalSet || !playedSetCompletionWarnings.contains(currentSet) {
                // Add to played warnings set
                playedSetCompletionWarnings.insert(currentSet)
                playedSetCompletionWarningsWithTime[currentSet] = now
                
                // Speak the set completion warning
                let setCompletionText = "Set \(currentSet) completing in 3, 2, 1, 0"
                
                // Play the speech
                let _ = audioManager.speakText(setCompletionText, rate: 0.5)
                
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
                    // Calculate how long the app was in background/inactive
                    let timeSinceStateChange = now.timeIntervalSince(lastStateChangeTime)
                    print("Time since state change: \(timeSinceStateChange) seconds")
                    
                    if timeSinceStateChange < minimumBackgroundTime {
                        // For very brief app switches, preserve the timer completely
                        print("Brief app switch (\(timeSinceStateChange)s), preserving timer state")
                        
                        // If the timer was somehow invalidated, restart it without adjustment
                        if timer == nil {
                            print("Timer was invalidated during brief app switch, restarting without adjustment")
                            startTimer()
                        } else {
                            // Update the lastTimerFireTime to prevent jumps on the next timer fire
                            lastTimerFireTime = now
                            print("Existing timer preserved, updated lastTimerFireTime")
                        }
                    } else {
                        // For longer background durations, perform full adjustment
                        print("Longer duration away (\(timeSinceStateChange)s), performing full adjustment")
                        
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
                
            @unknown default:
                break
        }
    }
    
    private func beginBackgroundTask() {
        endBackgroundTask()
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            print("Background task expired")
            self?.endBackgroundTask()
        }
        
        print("Started background task with ID: \(backgroundTaskID.rawValue)")
        
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session activated for background task")
        } catch {
            print("Failed to activate audio session for background: \(error.localizedDescription)")
        }
        
        setupBackgroundAudioRefresh()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            print("Ending background task with ID: \(backgroundTaskID.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func cleanupBackgroundResources() {
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        backgroundWarningTimes = []
        scheduledWarnings = []
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
                let nextSetNumber = setIndex + 1
                if nextSetNumber <= timerModel.sets {
                    phaseSequence.append((isLow: timerModel.isLowIntensity, isLastInSet: false, setNumber: nextSetNumber))
                    phaseSequence.append((isLow: !timerModel.isLowIntensity, isLastInSet: true, setNumber: nextSetNumber))
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
        print("Current set: \(timerModel.currentSet)/\(timerModel.sets), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High"), Low completed: \(timerModel.lowIntensityCompleted), High completed: \(timerModel.highIntensityCompleted)")
        print("Remaining warnings: \(scheduledWarnings.count)")
        
        guard !scheduledWarnings.isEmpty else { return }
        
        if audioManager.isAnyAudioPlaying() {
            return
        }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        for (index, warning) in scheduledWarnings.enumerated() {
            if now >= warning.time || now.timeIntervalSince(warning.time) > -0.5 {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                switch warning.type {
                case .phaseTransition:
                    playWarningSound()
                    print("Playing phase transition warning sound at \(now)")
                    
                case .setCompletion(let setNumber):
                    // Use the current set number from the model to ensure accuracy.
                    // Note: This may differ from the 'setNumber' parameter if the timer
                    // has advanced while in the background. We prioritize announcing
                    // the current timer state rather than what was scheduled.
                    let actualSetNumber = timerModel.currentSet
                    
                    // Log if there's a mismatch between scheduled and actual set numbers
                    if setNumber != actualSetNumber {
                        print("Note: Set completion was scheduled for set \(setNumber) but playing for current set \(actualSetNumber)")
                    }
                    
                    // Check if we've played this warning recently (within 10 seconds)
                    if let lastPlayedTime = playedSetCompletionWarningsWithTime[actualSetNumber],
                       now.timeIntervalSince(lastPlayedTime) < 10.0 {
                        print("Skipping duplicate set completion announcement for set \(actualSetNumber) - played \(now.timeIntervalSince(lastPlayedTime)) seconds ago")
                        break
                    }
                    
                    let isFinalSet = actualSetNumber == timerModel.sets
                    
                    // Only play if we haven't already played this set's completion warning or it's the final set
                    if isFinalSet || !playedSetCompletionWarnings.contains(actualSetNumber) {
                        playedSetCompletionWarnings.insert(actualSetNumber)
                        playedSetCompletionWarningsWithTime[actualSetNumber] = now
                        
                        let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
                        let _ = audioManager.speakText(setCompletionText, rate: 0.0)
                        print("Playing set completion announcement for set \(actualSetNumber) at \(now) (scheduled as set \(setNumber))")
                    } else {
                        print("Skipping duplicate set completion announcement for set \(actualSetNumber) at \(now)")
                    }
                }
                
                // Mark this index for removal
                triggeredIndices.append(index)
                
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
        if scheduledWarnings.isEmpty {
            print("All warnings played, stopping background check timer")
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
        }
    }
    
    private func adjustTimerForBackgroundTime() {
        let now = Date()
        let elapsedTime = Int(now.timeIntervalSince(lastActiveTimestamp))
        
        // Don't adjust if elapsed time is too small or suspiciously large
        guard elapsedTime >= Int(minimumBackgroundTime) && elapsedTime < 3600 else {
            print("Skipping timer adjustment - elapsed time: \(elapsedTime) seconds")
            lastActiveTimestamp = now
            return
        }
            
        print("Adjusting timer for background time: \(elapsedTime) seconds")
        
        var remainingTimeToProcess = elapsedTime
        var currentSetNumber = timerModel.currentSet
        var currentMin = timerModel.currentMinutes
        var currentSec = timerModel.currentSeconds
        var currentIntens = timerModel.isCurrentIntensityLow
        var lowPhaseCompleted = timerModel.lowIntensityCompleted
        var highPhaseCompleted = timerModel.highIntensityCompleted
        
        while remainingTimeToProcess > 0 && currentSetNumber <= timerModel.sets {
            let currentIntervalRemaining = currentMin * 60 + currentSec
            
            if remainingTimeToProcess >= currentIntervalRemaining {
                // This interval is completed
                remainingTimeToProcess -= currentIntervalRemaining
                
                if currentIntens {
                    lowPhaseCompleted = true
                } else {
                    highPhaseCompleted = true
                }
                
                if lowPhaseCompleted && highPhaseCompleted {
                    if currentSetNumber < timerModel.sets {
                        currentSetNumber += 1
                        lowPhaseCompleted = false
                        highPhaseCompleted = false
                    } else {
                        currentSetNumber = timerModel.sets // This ensures we know it's completed
                        currentMin = 0
                        currentSec = 0
                        remainingTimeToProcess = 0 // Stop processing
                        break
                    }
                }
                currentMin = timerModel.minutes
                currentSec = timerModel.seconds
                currentIntens.toggle()
                
            } else {
                // Partial completion of current interval
                let newRemainingSeconds = currentIntervalRemaining - remainingTimeToProcess
                currentMin = newRemainingSeconds / 60
                currentSec = newRemainingSeconds % 60
                remainingTimeToProcess = 0
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
        }
        
        lastActiveTimestamp = now
        print("Timer adjusted to: \(timerModel.currentMinutes):\(timerModel.currentSeconds), Set \(timerModel.currentSet)/\(timerModel.sets)")
    }
    
    private func setupBackgroundAudioRefresh() {
        // Create a timer that periodically reactivates the audio session
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.timerModel.isTimerRunning && !self.timerModel.isTimerCompleted {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    print("Periodically reactivated audio session")
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
            }
        }
    }
    
    // MARK: - Notification Methods
    
    private func scheduleCompletionNotification() {
        // If we've already scheduled a completion notification, don't schedule another one
        if hasScheduledCompletionNotification {
            print("Completion notification already scheduled, skipping")
            return
        }
        
        // Cancel any existing notifications first to prevent duplicates
        cancelPendingNotifications()
        
        // Calculate remaining time more accurately
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
    
    // More accurate calculation of total remaining time
    private func calculateTotalRemainingTime() -> Int {
        // Current phase remaining time
        let currentPhaseTimeRemaining = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // Start with current phase
        var totalRemainingSeconds = currentPhaseTimeRemaining
        
        // Track phases we need to account for
        var phasesRemaining = 0
        
        // Current set status
        let currentSet = timerModel.currentSet
        let isLowPhase = timerModel.isCurrentIntensityLow
        let lowCompleted = timerModel.lowIntensityCompleted
        let highCompleted = timerModel.highIntensityCompleted
        
        // Calculate remaining phases in current set
        if isLowPhase && !lowCompleted && !highCompleted {
            // We're in low phase, high phase still remains
            phasesRemaining += 1
        } else if !isLowPhase && lowCompleted && !highCompleted {
            // We're in high phase, no more phases in this set
            phasesRemaining += 0
        } else if isLowPhase && lowCompleted && !highCompleted {
            // We're in low phase (second time), no more phases in this set
            phasesRemaining += 0
        } else if !isLowPhase && !lowCompleted && !highCompleted {
            // We're in high phase (started with high), low phase still remains
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
