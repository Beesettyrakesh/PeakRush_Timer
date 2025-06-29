# PeakRush Timer - Services

The PeakRush Timer app includes two key service classes that handle audio playback and notifications, providing essential functionality for the timer experience.

## AudioManager

`AudioManager` is a singleton service responsible for sound playback, speech synthesis, and audio session management. It handles the complex requirements of playing audio in both foreground and background states.

### Core Properties

```swift
static let shared = AudioManager()
private var audioPlayer: AVAudioPlayer?
private var speechSynthesizer: AVSpeechSynthesizer?
private var wasPlayingWhenInterrupted = false
private var currentSoundURL: URL?
private var audioPlaybackPosition: TimeInterval = 0
private var isAudioCuePlaying = false
private var isSpeechPlaying = false
private var interruptionObserver: NSObjectProtocol?
private var speechCompletionHandler: (() -> Void)?
```

These properties track the state of audio playback, handle interruptions, and manage resources.

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

This method configures the audio session for background playback with options to mix with other audio and duck (lower volume of) other audio sources.

### Sound Playback Methods

```swift
func prepareSound(named filename: String, withExtension ext: String) -> Int { ... }
func playSound() -> Bool { ... }
func stopSound() { ... }
func isPlaying() -> Bool { ... }
func getRemainingPlaybackTime() -> TimeInterval { ... }
func pauseSound() { ... }
func resumeSound() -> Bool { ... }
```

These methods provide a complete interface for sound file management, including preparation, playback control, and state querying.

### Speech Synthesis Methods

```swift
func speakText(_ text: String, rate: Float = 0.0, pitch: Float = 1.0, completion: (() -> Void)? = nil) -> Bool { ... }
func stopSpeech() { ... }
func isSpeaking() -> Bool { ... }
```

These methods enable text-to-speech functionality with control over rate and pitch, along with completion handling.

### Interruption Handling

```swift
private func setupNotifications() {
    // Register for audio session interruption notifications
    interruptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification,
        object: nil,
        queue: .main
    ) { [weak self] notification in
        self?.handleAudioInterruption(notification)
    }
}

private func handleAudioInterruption(_ notification: Notification) {
    // Handle interruption began/ended cases
    // Save/restore playback state
    // Pause/resume audio as needed
}
```

This sophisticated interruption handling system manages audio session interruptions (like phone calls or other apps playing audio), preserving playback state and position.

### Delegate Implementations

```swift
// AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { ... }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) { ... }
}

// AVSpeechSynthesizerDelegate
extension AudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { ... }
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { ... }
}
```

These delegate implementations handle completion and error events for both audio playback and speech synthesis.

### Key Features

1. **Singleton Pattern**: Provides a single shared instance for app-wide audio management
2. **Background Audio**: Configured for playback when app is backgrounded
3. **Interruption Handling**: Manages audio session interruptions gracefully
4. **Dual Audio Types**: Handles both sound effects and speech synthesis
5. **State Preservation**: Maintains playback position during interruptions
6. **Completion Callbacks**: Supports completion handlers for speech synthesis

## NotificationService

`NotificationService` manages local notifications, providing a clean interface for scheduling alerts when the app is in the background.

### Core Methods

```swift
func requestNotificationPermission() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error {
            print("Notification permission error: \(error.localizedDescription)")
        }
    }
}

func sendLocalNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
    )

    UNUserNotificationCenter.current().add(request)
}

func scheduleNotification(title: String, body: String, timeInterval: TimeInterval, identifier: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: timeInterval,
        repeats: false
    )

    let request = UNNotificationRequest(
        identifier: identifier,
        content: content,
        trigger: trigger
    )

    UNUserNotificationCenter.current().add(request)
}

func cancelAllNotifications() {
    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
}
```

### Key Features

1. **Permission Management**: Handles requesting notification authorization
2. **Immediate Notifications**: Supports sending notifications with minimal delay
3. **Scheduled Notifications**: Enables time-based notification scheduling
4. **Cancellation**: Provides method to cancel pending notifications
5. **Identifier-Based**: Uses unique identifiers for notification management

## Service Integration

Both services are integrated into the application through the `TimerRunViewModel`, which coordinates their usage:

### Audio Integration

```swift
// In TimerRunViewModel
private let audioManager = AudioManager.shared

// Prepare sound
private func prepareWarningSound() {
    warningSoundDuration = audioManager.prepareSound(named: "notification", withExtension: "mp3")
}

// Play warning sound
private func playWarningSound() {
    if !audioManager.isPlaying() && !audioManager.isSpeaking() {
        timerModel.warningTriggered = true
        let success = audioManager.playSound()
        // Handle success/failure
    }
}

// Play speech announcement
private func checkAndPlaySetCompletionWarning() {
    // Logic to determine when to play
    let setCompletionText = "Set \(timerModel.currentSet) completing in 3, 2, 1, 0"
    let _ = audioManager.speakText(setCompletionText, rate: 0.5)
}
```

### Notification Integration

```swift
// In TimerRunViewModel
private let notificationService = NotificationService()

// Schedule completion notification
private func scheduleCompletionNotification() {
    // Calculate remaining time
    let totalRemainingSeconds = /* calculation */

    notificationService.scheduleNotification(
        title: "Workout Complete!",
        body: "You've completed all \(timerModel.sets) sets. Great job!",
        timeInterval: TimeInterval(totalRemainingSeconds),
        identifier: "workoutComplete"
    )
}

// Send immediate notification
private func completeTimer() {
    // Other completion logic

    if UIApplication.shared.applicationState == .background {
        notificationService.sendLocalNotification(
            title: "Workout Complete!",
            body: "You've completed all \(timerModel.sets) sets. Great job!"
        )
    }
}
```

## Background Operation Strategy

The services work together to provide a seamless experience when the app is in the background:

1. **Audio Session Management**:

   - `AudioManager` configures the session for background playback
   - Periodic reactivation keeps the audio session alive
   - Interruption handling preserves state across system events

2. **Background Audio Playback**:

   - Warning sounds and speech continue in background
   - Audio session category allows mixing with other apps
   - Playback position is tracked for resumption

3. **Notification Scheduling**:
   - Completion notifications are scheduled based on remaining workout time
   - Notifications are canceled when returning to foreground
   - Immediate notifications are sent for completed workouts in background

This coordinated approach ensures that users receive appropriate audio and visual feedback regardless of whether the app is in the foreground or background.
