# PeakRush Timer - Technical Notes

## 🔧 Background Processing Implementation

The PeakRush Timer app implements a sophisticated background processing system that allows the timer to continue functioning even when the app is backgrounded or the device is locked.

### Background Task Management

```swift
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
```

The app uses `UIBackgroundTaskIdentifier` to request additional execution time when entering the background. This allows the app to continue processing for a limited time beyond the standard background execution limits.

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

## 🔊 Audio System Architecture

### Audio Session Configuration

```swift
func setupAudioSession() {
    do {
        // Configure audio session for mixing with other audio
        try AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        print("Audio session configured for background playback with mixing")
    } catch {
        print("Failed to set up audio session: \(error.localizedDescription)")
    }
}
```

The audio session is configured with the `.playback` category to enable background audio, and the `.mixWithOthers` option to allow the app's audio to play alongside other audio sources (like music apps). The `.duckOthers` option reduces the volume of other audio sources when the app plays its sounds.

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

### Duplicate Prevention

```swift
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
    } else {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}
```

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

## 🔄 Error Handling

### Graceful Degradation

```swift
func playSound() -> Bool {
    // Ensure audio session is active
    do {
        try AVAudioSession.sharedInstance().setActive(true)
    } catch {
        print("Failed to activate audio session: \(error.localizedDescription)")
        return false
    }

    // If we don't have a prepared player but have a URL, try to create one
    if audioPlayer == nil, let url = currentSoundURL {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self
        } catch {
            print("Failed to recreate audio player: \(error.localizedDescription)")
            return false
        }
    }

    // Play the sound
    let success = audioPlayer?.play() ?? false

    if !success {
        print("Failed to play warning sound")
    }

    return success
}
```

The app implements robust error handling with graceful degradation, such as attempting to recreate the audio player if it's nil, and returning success/failure status that can be handled by the caller.

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
