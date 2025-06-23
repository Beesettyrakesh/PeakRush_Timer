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
        backgroundWarningTimes = []
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
            
        timerModel.isTimerRunning = true
        lastActiveTimestamp = Date()
        timerModel.warningTriggered = false
        backgroundWarningTimes = []
            
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    func pauseTimer() {
        timerModel.isTimerRunning = false
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
        endBackgroundTask()
    }
    
    func stopTimer() {
        timerModel.isTimerRunning = false
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
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
            
            if timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted {
                if timerModel.currentSet < timerModel.sets {
                    timerModel.currentSet += 1
                    timerModel.lowIntensityCompleted = false
                    timerModel.highIntensityCompleted = false
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
        timerModel.warningTriggered = true
        
        // Play the sound using AudioManager
        let success = audioManager.playSound()
        
        if success {
            print("Warning sound played for set \(timerModel.currentSet)")
        } else {
            print("Failed to play warning sound for set \(timerModel.currentSet)")
        }
    }
    
    private func stopWarningSound() {
        audioManager.stopSound()
        timerModel.warningTriggered = false
    }
    
    private func checkAndPlayWarningSound() {
        // If we're not at the final seconds of a set or warning already triggered, do nothing
        if timerModel.warningTriggered || timerModel.isTimerCompleted {
            return
        }
        
        // Calculate remaining time in current set
        let remainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // If remaining time equals our warning threshold, play the sound
        if remainingSeconds == warningSoundDuration {
            playWarningSound()
        }
    }
    
    // MARK: - Background Task Management
    
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
            case .active:
                // App came to foreground
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    // Stop background timer if it exists
                    backgroundCheckTimer?.invalidate()
                    backgroundCheckTimer = nil
                    backgroundWarningTimes = []
                    
                    adjustTimerForBackgroundTime()
                    cancelPendingNotifications()
                    
                    // Restart the timer if it's still supposed to be running
                    if !timerModel.isTimerCompleted && timerModel.currentSet <= timerModel.sets {
                        startTimer()
                    }
                }
                
                // Ensure audio session is active when returning to foreground
                audioManager.setupAudioSession()
                
                // End background task if it exists
                endBackgroundTask()
                
            case .background:
                // App went to background
                if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                    // Record the exact time we went to background
                    lastActiveTimestamp = Date()
                    // Pause the active timer
                    timer?.invalidate()
                    timer = nil
                    
                    beginBackgroundTask()
                    scheduleBackgroundWarnings()
                    
                    // Only schedule completion notification
                    scheduleCompletionNotification()
                }
            case .inactive:
                // App is transitioning between states - do nothing
                break
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
        backgroundCheckTimer?.invalidate()
        
        let now = Date()
        
        // Calculate current remaining time
        let currentRemainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
        
        // If there's enough time left in the current phase to play a warning
        if currentRemainingSeconds > warningSoundDuration {
            let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
            backgroundWarningTimes.append(warningTime)
            print("Scheduled warning for current phase at \(warningTime)")
        }
        
        // Track time offset for future warnings
        var timeOffset = TimeInterval(currentRemainingSeconds)
        
        // Calculate how many more phases we need to go through
        var remainingPhases = 0
        
        // Current set phases
        if timerModel.isCurrentIntensityLow {
            // We're in low phase, so we'll need the high phase too
            remainingPhases += 1
        }
        
        // Add two phases for each remaining set (low and high)
        remainingPhases += (timerModel.sets - timerModel.currentSet) * 2
        
        // Schedule warnings for all future phases
        var currentPhaseIsLow = timerModel.isCurrentIntensityLow
        
        for _ in 0..<remainingPhases {
            // Move to next phase
            currentPhaseIsLow.toggle()
            timeOffset += TimeInterval(timerModel.totalSeconds)
            
            // Schedule warning for this phase
            if timeOffset > TimeInterval(warningSoundDuration) {
                let warningTime = now.addingTimeInterval(timeOffset - TimeInterval(warningSoundDuration))
                backgroundWarningTimes.append(warningTime)
                print("Scheduled warning for future phase at \(warningTime)")
            }
        }
        
        // Log scheduled warning times
        print("Scheduled \(backgroundWarningTimes.count) warning sounds:")
        for (index, time) in backgroundWarningTimes.enumerated() {
            let timeInterval = time.timeIntervalSince(now)
            print("Warning \(index + 1): \(timeInterval) seconds from now")
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
        print("Remaining warnings: \(backgroundWarningTimes.count)")
        
        guard !backgroundWarningTimes.isEmpty else { return }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        // Check each scheduled warning time
        for (index, warningTime) in backgroundWarningTimes.enumerated() {
            // If the time has passed or is very close (within 0.5 seconds)
            if now >= warningTime || now.timeIntervalSince(warningTime) > -0.5 {
                // Ensure audio session is active before playing
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                // Play the warning sound
                playWarningSound()
                print("Playing scheduled warning sound \(index + 1) at \(now)")
                
                // Mark this index for removal
                triggeredIndices.append(index)
                
                // Only play one sound at a time to avoid overlap
                break
            }
        }
        
        // Remove triggered warnings (in reverse order to avoid index issues)
        for index in triggeredIndices.sorted(by: >) {
            if index < backgroundWarningTimes.count {
                backgroundWarningTimes.remove(at: index)
            }
        }
        
        // If all warnings have been played, stop the check timer
        if backgroundWarningTimes.isEmpty {
            print("All warnings played, stopping background check timer")
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
        }
    }
    
    private func adjustTimerForBackgroundTime() {
        let now = Date()
        let elapsedTime = Int(now.timeIntervalSince(lastActiveTimestamp))
        
        guard elapsedTime > 0 && elapsedTime < 3600 else {
            lastActiveTimestamp = now
            return
        }
        
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
        
        timerModel.currentSet = currentSetNumber
        timerModel.currentMinutes = max(0, currentMin)
        timerModel.currentSeconds = max(0, currentSec)
        timerModel.isCurrentIntensityLow = currentIntens
        timerModel.lowIntensityCompleted = lowPhaseCompleted
        timerModel.highIntensityCompleted = highPhaseCompleted
        timerModel.warningTriggered = false // Reset warning flag after background time
            
        // If we've completed all sets
        if timerModel.currentSet > timerModel.sets || (timerModel.currentSet == timerModel.sets && timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted) {
            timerModel.isTimerCompleted = true
            timerModel.isTimerRunning = false
            timerModel.currentMinutes = 0
            timerModel.currentSeconds = 0
        }
        
        lastActiveTimestamp = now
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
