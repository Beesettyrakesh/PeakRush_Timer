# PeakRush Timer - Technical Notes

## 🔧 Background Processing Implementation

The PeakRush Timer app implements a sophisticated background processing system that allows the timer to continue functioning even when the app is backgrounded or the device is locked.

### Enhanced Background Task Management

```swift
private func beginBackgroundTask() {
    endBackgroundTask()
    
    backgroundTaskStartTime = Date()
    
    // Create expiration handler that attempts to renew the task
    backgroundTaskExpirationHandler = { [weak self] in
        print("Background task expiring, attempting renewal")
        self?.renewBackgroundTask()
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
```

The app uses `UIBackgroundTaskIdentifier` to request additional execution time when entering the background. This allows the app to continue processing for a limited time beyond the standard background execution limits.

### Background Task Renewal

```swift
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
```

This innovative approach renews the background task before it expires, effectively extending the background execution time beyond the standard limits. This significantly improves reliability during long workouts.

## 🔄 Enhanced Timer Jumping Fix

The app implements a sophisticated solution to prevent timer jumps during brief app switches:

### Smart Timer Preservation

```swift
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
            
            // End background task if it exists
            endBackgroundTask()
            
        case .background:
            lastStateChangeTime = now
            print("App entered background at \(now)")
            isInBackgroundMode = true
                    
            if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                beginBackgroundTask()
                
                // Schedule warnings based on current timer state
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
```

This implementation never invalidates the timer for brief app switches, preserving the timer state completely for transitions under 3 seconds.

### Smart Timer Firing Compensation

```swift
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
```

This implementation compensates for irregular timer firing by detecting when more than 1.5 seconds have passed between fires and updating multiple times to catch up.

### Resource Cleanup

```swift
private func cleanupBackgroundResources() {
    backgroundCheckTimer?.invalidate()
    backgroundCheckTimer = nil
    backgroundWarningTimes = []
    scheduledWarnings = []
    print("Background resources cleaned up")
}
```

This method ensures proper cleanup of background resources when returning to the foreground, preventing resource leaks and duplicate warnings.

## 🔊 Enhanced Audio System Architecture

### Audio Session Configuration and Keep-Alive

```swift
func setupAudioSession() {
    // First deactivate any existing session
    try? AVAudioSession.sharedInstance().setActive(false)
    
    do {
        // Configure audio session for mixing with other audio
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .spokenAudio, // Changed from .default to .spokenAudio for better reliability
            options: [.mixWithOthers, .duckOthers, .interruptSpokenAudioAndMixWithOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        lastAudioSessionActivationTime = Date()
        audioSessionActivationAttempts = 0
        print("Audio session configured for background playback with mixing")
    } catch {
        print("Failed to set up audio session: \(error.localizedDescription)")
        
        // Retry with simpler configuration if the first attempt fails
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            lastAudioSessionActivationTime = Date()
            print("Audio session configured with fallback settings")
        } catch {
            print("Failed to set up audio session with fallback settings: \(error.localizedDescription)")
        }
    }
}
```

The audio session is configured with the `.playback` category to enable background audio, and the `.mixWithOthers` option to allow the app's audio to play alongside other audio sources (like music apps). The `.duckOthers` option reduces the volume of other audio sources when the app plays its sounds.

### Audio Session Keep-Alive Mechanism

```swift
// Start a timer to keep the audio session alive
func startAudioSessionKeepAlive() {
    stopAudioSessionKeepAlive()
    audioSessionKeepAliveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
        self?.refreshAudioSession()
    }
    RunLoop.current.add(audioSessionKeepAliveTimer!, forMode: .common)
    print("Audio session keep-alive timer started")
}

// Refresh the audio session periodically
private func refreshAudioSession() {
    // Only refresh if not currently playing audio
    if !isAnyAudioPlaying() {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            lastAudioSessionActivationTime = Date()
            audioSessionActivationAttempts = 0
            print("Audio session refreshed at \(Date())")
        } catch {
            print("Failed to refresh audio session: \(error)")
            // Reset audio session if too many failures
            if audioSessionActivationAttempts > 3 {
                resetAudioSession()
            }
            audioSessionActivationAttempts += 1
        }
    }
}
```

This innovative keep-alive mechanism periodically refreshes the audio session to prevent iOS from reclaiming audio resources during extended background operation. This significantly improves reliability for long workouts.

### Audio Session Health Monitoring

```swift
// Check if the audio session is healthy
func isAudioSessionHealthy() -> Bool {
    // Check if session was activated recently (within 60 seconds)
    if let lastActivation = lastAudioSessionActivationTime,
       Date().timeIntervalSince(lastActivation) < 60 {
        return true
    }
    
    // Try to check session status directly
    do {
        let isActive = AVAudioSession.sharedInstance().isOtherAudioPlaying == false
        return isActive
    } catch {
        print("Error checking audio session health: \(error)")
        return false
    }
}
```

This health monitoring system detects when the audio session becomes invalid, allowing the app to take corrective action before attempting to play audio. This prevents silent failures where audio warnings don't play.

### Interruption Handling

```swift
private func handleAudioInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
        return
    }

    switch type {
    case .began:
        // Interruption began (e.g., phone call or other app started playing audio)
        wasPlayingWhenInterrupted = audioPlayer?.isPlaying ?? false
        if wasPlayingWhenInterrupted {
            // Save current playback position
            audioPlaybackPosition = audioPlayer?.currentTime ?? 0
            audioPlayer?.pause()
            print("Audio interrupted - paused playback at position \(audioPlaybackPosition)")
        }

        // Also handle speech interruption
        if speechSynthesizer?.isSpeaking == true {
            speechSynthesizer?.pauseSpeaking(at: .immediate)
            print("Speech interrupted - paused speaking")
        }

    case .ended:
        // Interruption ended
        guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)

        // If we should resume and we were playing before
        if options.contains(.shouldResume) {
            // Resume playback from saved position if we were playing
            if wasPlayingWhenInterrupted, let player = audioPlayer {
                player.currentTime = audioPlaybackPosition
                player.play()
                print("Audio interruption ended - resumed playback from position \(audioPlaybackPosition)")
            }

            // Resume speech if it was interrupted
            if speechSynthesizer?.isSpeaking == false && isSpeechPlaying {
                speechSynthesizer?.continueSpeaking()
                print("Speech interruption ended - resumed speaking")
            }
        }

    @unknown default:
        break
    }
}
```

This comprehensive interruption handling system manages audio session interruptions (like phone calls or other apps playing audio), preserving playback state and position for both sound effects and speech synthesis.

## 🔄 Enhanced Background Warning System

The app implements a sophisticated background warning system with comprehensive documentation:

### Warning Scheduling

```swift
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
    // Clear existing warnings
    backgroundWarningTimes = []
    scheduledWarnings = []
    backgroundCheckTimer?.invalidate()
    
    let now = Date()
    
    // Schedule warnings for current phase
    let currentRemainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
    let isCurrentPhaseLastInSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                                 (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
    
    // Schedule phase transition warning if needed
    if currentRemainingSeconds > warningSoundDuration && !isCurrentPhaseLastInSet {
        let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
        scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
    }
    
    // Schedule set completion warning if needed
    if isCurrentPhaseLastInSet && currentRemainingSeconds > setCompletionWarningSeconds {
        let setCompletionWarningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - setCompletionWarningSeconds))
        scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, 
                                                type: .setCompletion(setNumber: timerModel.currentSet)))
    }
    
    // Calculate and schedule warnings for future phases
    // [Additional code for future phase scheduling]
    
    // Start background check timer
    backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        self?.checkBackgroundWarnings()
    }
    
    // Ensure timer runs in background
    if let timer = backgroundCheckTimer {
        RunLoop.current.add(timer, forMode: .common)
    }
}
```

### Warning Playback

```swift
/// Checks if any scheduled warnings should be played and triggers them if appropriate.
///
/// This method is called periodically by the backgroundCheckTimer to check if any
/// scheduled warnings should be played. When a warning time is reached:
/// - For phase transitions: A sound is played
/// - For set completions: A speech announcement is made using the CURRENT set number
///   from the timer model, not necessarily the set number that was stored when the
///   warning was scheduled. This ensures the announcement matches the actual timer state.
private func checkBackgroundWarnings() {
    // Skip if no warnings or audio is already playing
    guard !scheduledWarnings.isEmpty else { return }
    if audioManager.isAnyAudioPlaying() { return }
    
    let now = Date()
    var triggeredIndices: [Int] = []
    
    // Check each warning
    for (index, warning) in scheduledWarnings.enumerated() {
        if now >= warning.time || now.timeIntervalSince(warning.time) > -0.5 {
            // Ensure audio session is active
            try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            switch warning.type {
            case .phaseTransition:
                // Play warning sound
                playWarningSound()
                
            case .setCompletion(let setNumber):
                // Use current set number for accuracy
                let actualSetNumber = timerModel.currentSet
                
                // Check for duplicates using timestamp-based tracking
                if let lastPlayedTime = playedSetCompletionWarningsWithTime[actualSetNumber],
                   now.timeIntervalSince(lastPlayedTime) < 10.0 {
                    break
                }
                
                // Special handling for final set
                let isFinalSet = actualSetNumber == timerModel.sets
                
                // Play if final set or not played before
                if isFinalSet || !playedSetCompletionWarnings.contains(actualSetNumber) {
                    // Record that this warning was played
                    playedSetCompletionWarnings.insert(actualSetNumber)
                    playedSetCompletionWarningsWithTime[actualSetNumber] = now
                    
                    // Speak the announcement
                    let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
                    let _ = audioManager.speakText(setCompletionText, rate: 0.0)
                }
            }
            
            // Mark for removal
            triggeredIndices.append(index)
            break
        }
    }
    
    // Remove played warnings
    for index in triggeredIndices.sorted(by: >) {
        if index < scheduledWarnings.count {
            scheduledWarnings.remove(at: index)
        }
    }
    
    // Clean up if all warnings played
    if scheduledWarnings.isEmpty {
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
    }
}
```

## 🔔 Enhanced Notification System

The app implements a sophisticated notification system with dynamic buffer calculation:

### Total Remaining Time Calculation

```swift
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
    
    return totalRemainingSeconds
}
```

### Dynamic Buffer Calculation

```swift
private func scheduleCompletionNotification() {
    // Cancel existing notifications
    cancelPendingNotifications()
    
    var totalRemainingSeconds = calculateTotalRemainingTime()
    
    // For very short intervals, use a larger buffer
    let isShortInterval = timerModel.totalSeconds <= 15
    
    // Add a buffer to prevent premature notifications
    // Use a larger buffer (8 seconds) for short intervals, otherwise use 5 seconds
    let bufferSeconds = isShortInterval ? 8 : 5
    totalRemainingSeconds += bufferSeconds
    
    // For very short intervals (10 seconds or less), add a small additional buffer
    if timerModel.totalSeconds <= 10 {
        // Add 1 second per remaining phase/set to account for timing variations
        let totalPhasesRemaining = phasesRemaining + (completeSetsRemaining * 2)
        totalRemainingSeconds += totalPhasesRemaining
    }
    
    // Schedule notification
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
    }
}
```

### Enhanced Notification Deduplication

```swift
// Track sent notification history to prevent duplicates
private var recentNotificationHistory: [(identifier: String, timestamp: Date)] = []
private let notificationHistoryLimit = 10
private let notificationDeduplicationWindow: TimeInterval = 30.0 // 30 seconds

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
```

This sophisticated notification deduplication system tracks notification content (not just identifiers) to prevent duplicate notifications, even when they're generated from different code paths. The system maintains a history of recent notifications with timestamps and uses content-based keys for deduplication.

### Speech-Notification Coordination

```swift
private func completeTimer() {
    stopTimer()
    timerModel.isTimerCompleted = true
    
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
```

This innovative approach ensures that notifications are only sent after speech warnings have completed, preventing race conditions that could confuse users. The system uses completion handlers to coordinate the timing of speech and notifications.

## 🔄 SwiftUI Reactive Programming

### Binding Properties

```swift
var minutes: Binding<Int> {
    Binding(
        get: { self.timerModel.minutes },
        set: { self.timerModel.minutes = $0 }
    )
}
```

The app uses SwiftUI's `Binding` type to create two-way connections between UI controls and the underlying model properties. This enables reactive UI updates when the model changes.

### Dynamic UI Properties

```swift
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
```

The app uses computed properties to derive UI state from model state, enabling dynamic visual feedback based on the current timer state.

## 📝 Comprehensive Documentation

The app now includes comprehensive documentation for critical functions:

### Class-Level Documentation

```swift
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
///
/// Audio Session Management:
/// - The app implements a keep-alive mechanism to periodically refresh the audio session
/// - Health checks detect when the audio session becomes invalid
/// - Multiple retry attempts are used when audio session activation fails
/// - Background tasks are renewed before expiration to extend background execution time
/// - Adaptive refresh intervals optimize battery usage based on warning proximity
class TimerRunViewModel: ObservableObject {
    // Implementation
}
```

### Method Documentation

```swift
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
    // Implementation
}
```

### Inline Documentation

```swift
// Use the current set number from the model to ensure accuracy.
// Note: This may differ from the 'setNumber' parameter if the timer
// has advanced while in the background. We prioritize announcing
// the current timer state rather than what was scheduled.
let actualSetNumber = timerModel.currentSet
```

This comprehensive documentation ensures that the complex background processing logic is well-documented for future maintenance.

## 🔒 Memory Management

### Weak Self References

```swift
backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
    // Time expired - end the task
    print("Background task expired")
    self?.endBackgroundTask()
}
```

The app uses `[weak self]` capture lists in closures to prevent retain cycles and memory leaks, particularly in timer callbacks and background tasks.

### Resource Cleanup

```swift
deinit {
    if let observer = interruptionObserver {
        NotificationCenter.default.removeObserver(observer)
    }
}
```

The app properly cleans up resources in `deinit` methods, such as removing notification observers when objects are deallocated.

## 🔄 Enhanced Error Handling

### Robust Retry Mechanisms

```swift
private func checkBackgroundWarnings() {
    // Skip if no warnings or audio is already playing
    guard !scheduledWarnings.isEmpty else { return }
    if audioManager.isAnyAudioPlaying() { return }
    
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
                
            case .setCompletion(let setNumber):
                // Use current set number for accuracy
                let actualSetNumber = timerModel.currentSet
                
                // Check for duplicates
                if let lastPlayedTime = playedSetCompletionWarningsWithTime[actualSetNumber],
                   now.timeIntervalSince(lastPlayedTime) < 10.0 {
                    playbackSucceeded = true
                } else {
                    // Play speech with retry
                    for attempt in 1...3 {
                        let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
                        if audioManager.speakText(setCompletionText, rate: 0.3) {
                            playedSetCompletionWarnings.insert(actualSetNumber)
                            playedSetCompletionWarningsWithTime[actualSetNumber] = now
                            playbackSucceeded = true
                            break
                        }
                        Thread.sleep(forTimeInterval: 0.2)
                        // Try to refresh audio session before retry
                        audioManager.setupAudioSession()
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
    
    // Remove triggered warnings
    for index in triggeredIndices.sorted(by: >) {
        if index < scheduledWarnings.count {
            scheduledWarnings.remove(at: index)
        }
    }
}
```

The app implements robust retry mechanisms for audio playback, with multiple attempts and audio session refreshes between attempts. This significantly improves reliability during extended background operation.

### Graceful Degradation with Health Checks

```swift
// Method to ensure audio session is active for background operation
func ensureAudioSessionActive() -> Bool {
    // If session is already healthy, no need to reactivate
    if isAudioSessionHealthy() {
        return true
    }
    
    // Try to reactivate with multiple attempts
    for attempt in 1...3 {
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            lastAudioSessionActivationTime = Date()
            print("Audio session reactivated for background operation (attempt \(attempt))")
            return true
        } catch {
            print("Failed to ensure audio session is active (attempt \(attempt)): \(error.localizedDescription)")
            
            // Short delay before retry
            if attempt < 3 {
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
    }
    
    // If all attempts failed, try resetting the session
    resetAudioSession()
    
    // Check if reset helped
    do {
        let isActive = try AVAudioSession.sharedInstance().setActive(true)
        lastAudioSessionActivationTime = Date()
        return isActive
    } catch {
        print("Failed to activate audio session even after reset: \(error)")
        return false
    }
}
```

The app implements health checks to detect when the audio session becomes invalid, with multiple layers of recovery including session reactivation, delays between attempts, and complete session reset as a last resort.

## 📱 iOS Integration

### App Delegate Integration

```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
```

The app uses SwiftUI's `@UIApplicationDelegateAdaptor` property wrapper to integrate a traditional `UIApplicationDelegate` with the SwiftUI app lifecycle.

### Environment Values

```swift
@Environment(\.dismiss) private var dismiss
@Environment(\.scenePhase) private var scenePhase
```

The app leverages SwiftUI's environment values to access system functionality like navigation dismissal and scene phase monitoring.

## 🧪 Unit Testing Implementation

The app now includes a comprehensive unit testing suite that tests all major components of the application. The testing approach addresses several challenges specific to iOS development, particularly around testing code that interacts with system frameworks.

### TestableAudioManager Pattern

```swift
class TestableAudioManager: AudioManager {
    var mockIsPlaying = false
    var mockIsSpeaking = false
    
    // Override the methods we want to test
    override func isPlaying() -> Bool {
        return mockIsPlaying
    }
    
    override func isSpeaking() -> Bool {
        return mockIsSpeaking
    }
    
    // This is the method that was causing the EXC_BAD_ACCESS error
    override func isAnyAudioPlaying() -> Bool {
        return isPlaying() || isSpeaking()
    }
    
    // Override this to avoid actual AVAudioSession calls
    override func ensureAudioSessionActive() -> Bool {
        return true
    }
    
    // Override to avoid actual AVAudioSession calls
    override func setupAudioSession() {
        // No-op for testing
    }
    
    // Additional mock methods...
}
```

This pattern uses inheritance to create a testable version of a class that interacts with system frameworks. By overriding methods that would normally interact with system frameworks, we can test the logic of the class without actually making those system calls.

### Interface-Based Mocking

```swift
// Instead of subclassing AVAudioPlayer, create a class that mimics its interface
class MockAVAudioPlayer {
    var prepareToPlayCalled = false
    var playCalled = false
    var stopCalled = false
    var pauseCalled = false
    
    var mockIsPlaying = false
    var mockDuration: TimeInterval = 5.0
    var mockCurrentTime: TimeInterval = 0.0
    var mockVolume: Float = 1.0
    var delegate: AVAudioPlayerDelegate?
    
    func prepareToPlay() -> Bool {
        prepareToPlayCalled = true
        return true
    }
    
    func play() -> Bool {
        playCalled = true
        mockIsPlaying = true
        return true
    }
    
    // Additional methods...
}
```

For system classes that are difficult to subclass or mock directly, we create standalone mock classes that implement the same interface. This approach avoids the issues that can occur when trying to subclass system classes with unavailable initializers.

### Protocol-Based Approach for Notification Center

```swift
// Define a protocol for UNUserNotificationCenter functionality
protocol UNUserNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void)
}

// Make UNUserNotificationCenter conform to our protocol
extension UNUserNotificationCenter: UNUserNotificationCenterProtocol {}

// Create a mock implementation
class MockUNUserNotificationCenter: UNUserNotificationCenterProtocol {
    var requestAuthorizationCalled = false
    var addRequestCalled = false
    var lastAddedRequest: UNNotificationRequest?
    
    // Implementation of protocol methods...
}
```

This approach uses protocols to define the interface we need to test, then creates mock implementations of those protocols. This is particularly useful for system classes that provide singleton instances, like UNUserNotificationCenter.

### UI Component Testing

```swift
// Before:
var circleColor: LinearGradient {
    if !timerModel.isTimerRunning && !timerModel.isTimerCompleted {
        return LinearGradient(
            colors: [.gray, .gray],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    // Additional cases...
}

// After:
var circleColor: Color {
    if timerModel.isTimerCompleted {
        return Color.blue
    } else if !timerModel.isTimerRunning {
        return Color.gray
    } else {
        return timerModel.isCurrentIntensityLow ? Color.green : Color.red
    }
}
```

For UI components, we've simplified the implementation to make it more testable. In this example, we changed a property from returning a LinearGradient to returning a Color, which makes it easier to test the actual color values.

### Test Structure

The unit tests are organized by component type:

1. **Models**: Tests for data structures and business logic
   ```swift
   class TimerModelTests: XCTestCase {
       func testInitialization() {
           // Test code...
       }
       
       func testComputedProperties() {
           // Test code...
       }
   }
   ```

2. **ViewModels**: Tests for presentation logic and state management
   ```swift
   class TimerRunViewModelTests: XCTestCase {
       func testCircleColorWhenNotRunning() {
           // Test code...
       }
       
       func testStartTimer() {
           // Test code...
       }
   }
   ```

3. **Services**: Tests for external functionality like audio and notifications
   ```swift
   class AudioManagerTests: XCTestCase {
       func testPlaySound() {
           // Test code...
       }
       
       func testSpeakText() {
           // Test code...
       }
   }
   ```

4. **Utilities**: Tests for helper functions and formatters
   ```swift
   class TimeFormatterTests: XCTestCase {
       func testFormatTimeString() {
           // Test code...
       }
   }
   ```

### Testing Challenges and Solutions

1. **System Framework Interactions**: Testing code that interacts with system frameworks like AVFoundation and UserNotifications is challenging because these frameworks often use singletons and have methods that can't be easily mocked.
   - **Solution**: Use a combination of inheritance, interface-based mocking, and protocol-based approaches to create testable versions of classes that interact with system frameworks.

2. **Memory Access Issues**: Attempting to mock system classes directly can lead to memory access issues (EXC_BAD_ACCESS errors).
   - **Solution**: Create standalone mock classes that implement the same interface rather than subclassing system classes.

3. **Private Method Testing**: Testing private methods directly is challenging in Swift.
   - **Solution**: Use a combination of public method testing and reflection to test private methods indirectly.

4. **Asynchronous Testing**: Testing asynchronous code like timers and notifications is challenging.
   - **Solution**: Use XCTest's expectation API to wait for asynchronous operations to complete.

5. **UI Component Testing**: Testing UI components that use complex SwiftUI types like LinearGradient can be challenging.
   - **Solution**: Simplify the implementation to use more testable types like Color.
