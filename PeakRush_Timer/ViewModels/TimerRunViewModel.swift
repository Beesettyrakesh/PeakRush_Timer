// File: PeakRush_Timer/ViewModels/TimerRunViewModel.swift

import Foundation
import SwiftUI
import AVFoundation
import UserNotifications

class TimerRunViewModel: ObservableObject {
    @Published var timerModel: TimerModel
    
    private var timer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var lastActiveTimestamp: Date = Date()
    private var backgroundWarningTimes: [Date] = []
    private var backgroundCheckTimer: Timer?
    private var warningSoundDuration: Int = 0
    private var lastStateChangeTime: Date = Date()
    private var minimumBackgroundTime: TimeInterval = 3.0 // Increased to 3.0 seconds for better handling of brief app switches
    private var lastTimerFireTime: Date = Date() // Track when the timer last fired
    
    // New properties for set completion warning
    private var setCompletionWarningTriggered = false
    private var setCompletionWarningSeconds = 5 // Play warning 5 seconds before set completion
    
    // Enum to distinguish between warning types for background mode
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
            notificationService.sendLocalNotification(
                title: "Workout Complete!",
                body: "You've completed all \(timerModel.sets) sets. Great job!"
            )
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
            
            // Speak the set completion warning
            let setCompletionText = "Set \(timerModel.currentSet) completing in 3, 2, 1, 0"
            
            // Play the speech
            let _ = audioManager.speakText(setCompletionText, rate: 0.5)
            
            print("Playing set completion announcement for set \(timerModel.currentSet)")
        }
    }
    
    // MARK: - Background Task Management
    
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        let now = Date()
        
        switch newPhase {
            case .active:
                print("App became active at \(now)")
                // App came to foreground
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
                        backgroundCheckTimer?.invalidate()
                        backgroundCheckTimer = nil
                        backgroundWarningTimes = []
                        scheduledWarnings = []
                        
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
                // Record the time we entered background
                lastStateChangeTime = now
                print("App entered background at \(now)")
                        
                // App went to background
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    // NEVER invalidate the timer for background state
                    // This is critical for preventing timer jumps during brief app switches
                    
                    beginBackgroundTask()
                    scheduleBackgroundWarnings()
                    
                    // Only schedule completion notification
                    scheduleCompletionNotification()
                }
                        
            case .inactive:
                // App is transitioning between states
                print("App became inactive at \(now)")
                
                // Record the time we became inactive
                // This is important because brief app switches often go through inactive state
                lastStateChangeTime = now
                
                // Do not invalidate the timer here either
                
            @unknown default:
                break
        }
    }
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
        
        // Request background execution time
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            // Time expired - end the task
            print("Background task expired")
            self?.endBackgroundTask()
        }
        
        print("Started background task with ID: \(backgroundTaskID.rawValue)")
        
        // Ensure audio session is active for background playback
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session activated for background task")
        } catch {
            print("Failed to activate audio session for background: \(error.localizedDescription)")
        }
        
        // Set up periodic audio session refresh
        setupBackgroundAudioRefresh()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            print("Ending background task with ID: \(backgroundTaskID.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func scheduleBackgroundWarnings() {
        // Clear any existing scheduled warnings
        backgroundWarningTimes = []
        scheduledWarnings = []
        backgroundCheckTimer?.invalidate()
        
        let now = Date()
        
        // Calculate current remaining time
        let currentRemainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // Determine if current phase is the last in the set
        let isCurrentPhaseLastInSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                                     (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
        
        // If there's enough time left in the current phase to play a warning
        if currentRemainingSeconds > warningSoundDuration {
            // Only schedule phase transition warning if this is not the last phase of the set
            if !isCurrentPhaseLastInSet {
                let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
                scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
                print("Scheduled phase transition warning at \(warningTime)")
            }
        }
        
        // Schedule set completion warning if this is the last phase of the set
        if isCurrentPhaseLastInSet && currentRemainingSeconds > setCompletionWarningSeconds {
            let setCompletionWarningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - setCompletionWarningSeconds))
            scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: timerModel.currentSet)))
            print("Scheduled set completion warning at \(setCompletionWarningTime)")
        }
        
        // Track time offset for future warnings
        var timeOffset = TimeInterval(currentRemainingSeconds)
        
        // Calculate how many more phases we need to go through
        var phaseSequence: [(isLow: Bool, isLastInSet: Bool, setNumber: Int)] = []
        
        // Current phase
        let currentPhaseIsLow = timerModel.isCurrentIntensityLow
        let currentSetNumber = timerModel.currentSet
        
        // If current phase is not the last in set, we need to add the next phase in this set
        if !isCurrentPhaseLastInSet {
            phaseSequence.append((isLow: !currentPhaseIsLow, isLastInSet: true, setNumber: currentSetNumber))
        }
        
        // Add two phases for each remaining set (low and high)
        for setIndex in currentSetNumber..<timerModel.sets {
            if setIndex > currentSetNumber || (setIndex == currentSetNumber && isCurrentPhaseLastInSet) {
                // For future sets, add both low and high phases
                let nextSetNumber = setIndex + 1
                if nextSetNumber <= timerModel.sets {
                    phaseSequence.append((isLow: timerModel.isLowIntensity, isLastInSet: false, setNumber: nextSetNumber))
                    phaseSequence.append((isLow: !timerModel.isLowIntensity, isLastInSet: true, setNumber: nextSetNumber))
                }
            }
        }
        
        // Schedule warnings for all future phases
        for (index, phase) in phaseSequence.enumerated() {
            // Move to next phase
            timeOffset += TimeInterval(timerModel.totalSeconds)
            
            // Schedule regular interval warning for this phase if it's not the last in the set
            if !phase.isLastInSet && timeOffset > TimeInterval(warningSoundDuration) {
                let warningTime = now.addingTimeInterval(timeOffset - TimeInterval(warningSoundDuration))
                scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
                print("Scheduled phase transition warning for future phase \(index + 1) at \(warningTime)")
            }
            
            // Schedule set completion warning if this is the last phase of a set
            if phase.isLastInSet && timeOffset > TimeInterval(setCompletionWarningSeconds) {
                let setCompletionWarningTime = now.addingTimeInterval(timeOffset - TimeInterval(setCompletionWarningSeconds))
                scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: phase.setNumber)))
                print("Scheduled set completion warning for future phase \(index + 1) at \(setCompletionWarningTime)")
            }
        }
        
        // Convert to simple backgroundWarningTimes for compatibility with existing code
        backgroundWarningTimes = scheduledWarnings.map { $0.time }
        
        // Log scheduled warning times
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
        
        // Start a timer that checks frequently if it's time to play a warning sound
        backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkBackgroundWarnings()
        }
        
        // Make sure the timer runs even when app is in background
        if let timer = backgroundCheckTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func checkBackgroundWarnings() {
        // Add debug logging here
        print("Current set: \(timerModel.currentSet)/\(timerModel.sets), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High"), Low completed: \(timerModel.lowIntensityCompleted), High completed: \(timerModel.highIntensityCompleted)")
        print("Remaining warnings: \(scheduledWarnings.count)")
        
        guard !scheduledWarnings.isEmpty else { return }
        
        // If audio is already playing, don't start another warning
        if audioManager.isAnyAudioPlaying() {
            return
        }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        // Check each scheduled warning time
        for (index, warning) in scheduledWarnings.enumerated() {
            // If the time has passed or is very close (within 0.5 seconds)
            if now >= warning.time || now.timeIntervalSince(warning.time) > -0.5 {
                // Ensure audio session is active before playing
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                // Play the appropriate warning based on type
                switch warning.type {
                case .phaseTransition:
                    // Play the warning sound for phase transitions
                    playWarningSound()
                    print("Playing phase transition warning sound at \(now)")
                    
                case .setCompletion(let setNumber):
                    // Play the speech announcement for set completion
                    let setCompletionText = "Set \(setNumber) completing in 3, 2, 1, 0"
                    let _ = audioManager.speakText(setCompletionText, rate: 0.5)
                    print("Playing set completion announcement for set \(setNumber) at \(now)")
                }
                
                // Mark this index for removal
                triggeredIndices.append(index)
                
                // Only play one sound at a time to avoid overlap
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
        let currentPhaseTimeRemaining = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        var totalRemainingSeconds = currentPhaseTimeRemaining
        
        if timerModel.isCurrentIntensityLow && !timerModel.lowIntensityCompleted {
            totalRemainingSeconds += timerModel.totalSeconds
        }
        
        // Add time for remaining full sets
        let completeSetsRemaining = timerModel.sets - timerModel.currentSet
        if completeSetsRemaining > 0 {
            // Each remaining set has two phases (low and high intensity)
            totalRemainingSeconds += completeSetsRemaining * timerModel.totalSeconds * 2
        }
        
        // Schedule final completion notification
        if totalRemainingSeconds > 0 {
            notificationService.scheduleNotification(
                title: "Workout Complete!",
                body: "You've completed all \(timerModel.sets) sets. Great job!",
                timeInterval: TimeInterval(totalRemainingSeconds),
                identifier: "workoutComplete"
            )
            print("Scheduling completion notification in \(totalRemainingSeconds) seconds")
        }
    }
    
    private func cancelPendingNotifications() {
        notificationService.cancelAllNotifications()
    }
}
