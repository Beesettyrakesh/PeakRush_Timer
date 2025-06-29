# PeakRush Timer - Models

## TimerModel

The `TimerModel` is the core data structure of the PeakRush Timer application, responsible for maintaining both the configuration parameters and runtime state of the interval timer.

### Configuration Parameters

```swift
// Configuration parameters
var minutes: Int
var seconds: Int
var sets: Int
var isLowIntensity: Bool
```

| Parameter        | Type | Description                                                            |
| ---------------- | ---- | ---------------------------------------------------------------------- |
| `minutes`        | Int  | Minutes component of the interval duration                             |
| `seconds`        | Int  | Seconds component of the interval duration                             |
| `sets`           | Int  | Number of sets to complete (each set = 1 low + 1 high intensity phase) |
| `isLowIntensity` | Bool | Whether to start with low intensity (true) or high intensity (false)   |

### Runtime State

```swift
// Runtime state
var currentMinutes: Int
var currentSeconds: Int
var currentSet: Int
var isCurrentIntensityLow: Bool
var lowIntensityCompleted: Bool
var highIntensityCompleted: Bool
var isTimerRunning: Bool
var isTimerCompleted: Bool
var warningTriggered: Bool
```

| State Variable           | Type | Description                                                        |
| ------------------------ | ---- | ------------------------------------------------------------------ |
| `currentMinutes`         | Int  | Current minutes remaining in the active phase                      |
| `currentSeconds`         | Int  | Current seconds remaining in the active phase                      |
| `currentSet`             | Int  | Current set number (1-based index)                                 |
| `isCurrentIntensityLow`  | Bool | Whether the current phase is low intensity                         |
| `lowIntensityCompleted`  | Bool | Whether the low intensity phase of the current set is completed    |
| `highIntensityCompleted` | Bool | Whether the high intensity phase of the current set is completed   |
| `isTimerRunning`         | Bool | Whether the timer is currently running                             |
| `isTimerCompleted`       | Bool | Whether the entire workout has been completed                      |
| `warningTriggered`       | Bool | Whether the warning sound has been triggered for the current phase |

### Computed Properties

```swift
// Computed properties
var totalSeconds: Int { return minutes * 60 + seconds }
var totalWorkoutDuration: Int { return totalSeconds * 2 * sets }
var totalWorkoutMinutes: Int { return totalWorkoutDuration / 60 }
var totalWorkoutSeconds: Int { return totalWorkoutDuration % 60 }
var isConfigurationValid: Bool { return sets > 0 && (minutes > 0 || seconds > 0) }
var currentTotalSeconds: Int { return currentMinutes * 60 + currentSeconds }
var isSetCompleted: Bool { return lowIntensityCompleted && highIntensityCompleted }
```

| Computed Property      | Return Type | Description                                                    |
| ---------------------- | ----------- | -------------------------------------------------------------- |
| `totalSeconds`         | Int         | Total seconds in one interval (minutes \* 60 + seconds)        |
| `totalWorkoutDuration` | Int         | Total seconds for the entire workout (totalSeconds _ 2 _ sets) |
| `totalWorkoutMinutes`  | Int         | Minutes component of the total workout duration                |
| `totalWorkoutSeconds`  | Int         | Seconds component of the total workout duration                |
| `isConfigurationValid` | Bool        | Whether the current configuration is valid to start a workout  |
| `currentTotalSeconds`  | Int         | Total seconds remaining in the current phase                   |
| `isSetCompleted`       | Bool        | Whether both phases of the current set are completed           |

### Initialization

```swift
// Initialize with default values
init(minutes: Int = 0, seconds: Int = 0, sets: Int = 0, isLowIntensity: Bool = true) {
    self.minutes = minutes
    self.seconds = seconds
    self.sets = sets
    self.isLowIntensity = isLowIntensity

    // Initialize runtime state
    self.currentMinutes = minutes
    self.currentSeconds = seconds
    self.currentSet = 1
    self.isCurrentIntensityLow = isLowIntensity
    self.lowIntensityCompleted = false
    self.highIntensityCompleted = false
    self.isTimerRunning = false
    self.isTimerCompleted = false
    self.warningTriggered = false
}
```

The initializer accepts optional parameters with default values, making it flexible for different initialization scenarios.

### Key Behaviors

1. **Configuration Validation**: The `isConfigurationValid` computed property ensures that a workout can only start with valid parameters (at least one set and non-zero duration).

2. **Phase Tracking**: The model tracks which phases (low/high intensity) have been completed within the current set.

3. **Set Completion Logic**: The `isSetCompleted` computed property determines when both phases of a set are completed.

4. **Time Calculations**: Various computed properties handle time conversions and calculations.

5. **State Management**: The model maintains flags for the current running state and completion status.

### Usage Patterns

The `TimerModel` is primarily used in two contexts:

1. **Configuration Context**: In `TimerConfigViewModel`, where user inputs are bound to the model's configuration parameters.

2. **Execution Context**: In `TimerRunViewModel`, where the runtime state is continuously updated as the timer progresses.

### Data Flow

```
User Input → TimerConfigViewModel → TimerModel → TimerRunViewModel → UI Updates
```

The model serves as the single source of truth for both the configuration and runtime state of the timer, ensuring consistency across the application.
