# PeakRush Timer - ViewModels

The PeakRush Timer app follows the MVVM architecture pattern with two primary ViewModels that handle the business logic for timer configuration and execution.

## TimerConfigViewModel

`TimerConfigViewModel` manages the configuration state of the timer and provides binding interfaces for the UI controls in `TimerConfigView`.

### Core Properties

```swift
@Published var timerModel = TimerModel()
```

The ViewModel maintains a single source of truth with a `TimerModel` instance that holds all configuration parameters.

### Binding Properties

```swift
var minutes: Binding<Int> {
    Binding(
        get: { self.timerModel.minutes },
        set: { self.timerModel.minutes = $0 }
    )
}

var seconds: Binding<Int> {
    Binding(
        get: { self.timerModel.seconds },
        set: { self.timerModel.seconds = $0 }
    )
}

var sets: Binding<Int> {
    Binding(
        get: { self.timerModel.sets },
        set: { self.timerModel.sets = $0 }
    )
}

var isLowIntensity: Binding<Bool> {
    Binding(
        get: { self.timerModel.isLowIntensity },
        set: { self.timerModel.isLowIntensity = $0 }
    )
}
```

These binding properties create two-way connections between SwiftUI controls and the underlying model properties, allowing for reactive UI updates.

### Computed Properties

```swift
var isConfigurationValid: Bool {
    return timerModel.isConfigurationValid
}

var totalWorkoutDuration: Int {
    return timerModel.totalWorkoutDuration
}

var totalMinutes: Int {
    return timerModel.totalWorkoutMinutes
}

var totalSeconds: Int {
    return timerModel.totalWorkoutSeconds
}
```

These computed properties expose model calculations to the view layer, enabling real-time feedback as the user configures the timer.

### Factory Method

```swift
func createTimerRunViewModel() -> TimerRunViewModel {
    return TimerRunViewModel(timerModel: timerModel)
}
```

This factory method creates a new `TimerRunViewModel` instance with the current timer configuration, facilitating the transition from configuration to execution.

### Key Responsibilities

1. **Data Binding**: Provides SwiftUI binding interfaces for UI controls
2. **Validation**: Exposes configuration validity status
3. **Calculation**: Computes derived values like total workout duration
4. **Factory**: Creates the execution ViewModel with configured parameters

## TimerRunViewModel

`TimerRunViewModel` handles the complex logic of timer execution, including background processing, audio cues, and state transitions.

### Core Properties

```swift
@Published var timerModel: TimerModel
private var timer: Timer?
private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
private var lastActiveTimestamp: Date = Date()
private var backgroundWarningTimes: [Date] = []
private var backgroundCheckTimer: Timer?
private var warningSoundDuration: Int = 0
private var lastStateChangeTime: Date = Date()
private var minimumBackgroundTime: TimeInterval = 1.0
private var setCompletionWarningTriggered = false
private var setCompletionWarningSeconds = 5
private var scheduledWarnings: [ScheduledWarning] = []
private let notificationService = NotificationService()
private let audioManager = AudioManager.shared
```

These properties manage the timer state, background processing, audio cues, and service dependencies.

### UI-Related Computed Properties

```swift
var circleColor: LinearGradient { ... }
var intensityText: String { ... }
var intensityColor: Color { ... }
var iconColor: Color { ... }
```

These properties provide dynamic UI elements based on the current timer state, enabling visual feedback during the workout.

### Timer Control Methods

```swift
func initializeTimer() { ... }
func startTimer() { ... }
func pauseTimer() { ... }
func stopTimer() { ... }
func resetTimer() { ... }
```

These public methods provide the interface for controlling the timer's execution state.

### Private Implementation Methods

```swift
private func updateTimer() { ... }
private func completeTimer() { ... }
private func prepareWarningSound() { ... }
private func playWarningSound() { ... }
private func stopWarningSound() { ... }
private func checkAndPlayWarningSound() { ... }
private func checkAndPlaySetCompletionWarning() { ... }
```

These methods handle the internal logic of timer updates, completion handling, and audio cue management.

### Background Processing Methods

```swift
func handleScenePhaseChange(_ newPhase: ScenePhase) { ... }
private func beginBackgroundTask() { ... }
private func endBackgroundTask() { ... }
private func scheduleBackgroundWarnings() { ... }
private func checkBackgroundWarnings() { ... }
private func adjustTimerForBackgroundTime() { ... }
private func setupBackgroundAudioRefresh() { ... }
```

These methods manage the complex logic of background execution, including state preservation, audio scheduling, and time adjustment.

### Notification Methods

```swift
private func scheduleCompletionNotification() { ... }
private func cancelPendingNotifications() { ... }
```

These methods handle the scheduling and cancellation of push notifications for workout completion.

### Key Responsibilities

1. **Timer Management**: Controls the timer lifecycle and updates
2. **State Transitions**: Manages phase and set transitions
3. **Audio Cues**: Schedules and plays sounds and speech at appropriate times
4. **Background Processing**: Handles app state transitions and background execution
5. **UI State**: Provides dynamic UI properties based on timer state
6. **Notifications**: Schedules push notifications for background completion

### Background Processing Strategy

The ViewModel implements a sophisticated background processing strategy:

1. When the app enters the background:

   - Pause the active timer
   - Begin a background task
   - Schedule audio warnings for future phase transitions
   - Schedule a completion notification

2. When the app returns to the foreground:

   - Calculate elapsed background time
   - Adjust timer state based on elapsed time
   - Cancel pending notifications
   - Restart the timer

3. During background execution:
   - Periodically check if it's time to play warning sounds
   - Maintain audio session activation
   - Track which warnings have been played

### Audio Strategy

The ViewModel coordinates with `AudioManager` to provide audio feedback:

1. **Phase Transition Warnings**: Play a sound N seconds before a phase ends
2. **Set Completion Announcements**: Use speech synthesis for countdown
3. **Background Audio**: Schedule and play sounds even when app is backgrounded
4. **Interruption Handling**: Manage audio session interruptions

## ViewModel Interaction

The ViewModels interact in a one-directional flow:

```
TimerConfigViewModel → createTimerRunViewModel() → TimerRunViewModel
```

The configuration ViewModel creates the execution ViewModel with the configured timer model, ensuring a clean handoff of state.

## Reactive Programming Pattern

Both ViewModels leverage SwiftUI's reactive programming model:

1. **@Published Properties**: Trigger UI updates when changed
2. **Bindings**: Create two-way connections between UI and data
3. **Computed Properties**: Derive UI state from model state
4. **ObservableObject Protocol**: Enable SwiftUI's observation mechanism

This reactive approach ensures that the UI always reflects the current state of the timer, providing immediate feedback to the user.
