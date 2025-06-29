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

### Time Adjustment Algorithm

```swift
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
}
```

This sophisticated algorithm calculates how the timer state should be adjusted based on the elapsed time while the app was in the background. It processes each interval and set sequentially, accounting for phase transitions and set completions.

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

## 🔄 Background Warning Scheduling

```swift
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

    // Start a timer that checks frequently if it's time to play a warning sound
    backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
        self?.checkBackgroundWarnings()
    }

    // Make sure the timer runs even when app is in background
    if let timer = backgroundCheckTimer {
        RunLoop.current.add(timer, forMode: .common)
    }
}
```

This complex scheduling system pre-calculates all future warning times for both phase transitions and set completions, then sets up a timer to check if it's time to play each warning.

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

## 🔄 Scene Phase Handling

```swift
func handleScenePhaseChange(_ newPhase: ScenePhase) {
    let now = Date()

    switch newPhase {
        case .active:
            // App came to foreground
            if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                // Calculate how long the app was in background
                let backgroundDuration = now.timeIntervalSince(lastStateChangeTime)

                // Only process background time if the app was in background for a meaningful duration
                if backgroundDuration >= minimumBackgroundTime {
                    // Stop background timer if it exists
                    backgroundCheckTimer?.invalidate()
                    backgroundCheckTimer = nil
                    backgroundWarningTimes = []
                    scheduledWarnings = []

                    adjustTimerForBackgroundTime()
                    cancelPendingNotifications()
                }

                // Restart the timer if it's still supposed to be running
                if !timerModel.isTimerCompleted && timerModel.currentSet <= timerModel.sets {
                    startTimer()
                }
            }

            // End background task if it exists
            endBackgroundTask()

    case .background:
        // Record the time we entered background
        lastStateChangeTime = now

        // App went to background
        if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
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
```

The app uses SwiftUI's `ScenePhase` environment value to detect when the app transitions between foreground and background states, enabling appropriate actions to be taken.

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

These technical implementations demonstrate the sophisticated engineering behind the PeakRush Timer app, enabling robust operation across all app states while maintaining clean separation of concerns and testability.
