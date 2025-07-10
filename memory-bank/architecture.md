# PeakRush Timer - Technical Architecture

## 🏗️ MVVM Architecture Overview

The PeakRush Timer follows a clean MVVM (Model-View-ViewModel) architecture pattern with clear separation of concerns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Views       │◄──►│   ViewModels    │◄──►│     Models      │
│   (SwiftUI)     │    │(ObservableObject)│    │   (Structs)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│    Services     │    │   Utilities     │    │   Resources     │
│ (Singletons)    │    │   (Helpers)     │    │ (Assets/Audio)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📱 Application Lifecycle

### App Entry Point

- **PeakRush_TimerApp.swift**: Main app struct with `@main` attribute
- **AppDelegate.swift**: Handles app lifecycle events and initial setup
- **ContentView.swift**: Root navigation container

### Navigation Flow

```
ContentView (NavigationStack)
    └── TimerConfigView
            └── TimerRunView (NavigationLink)
```

## 🔄 Data Flow Architecture

### State Management Pattern

```
User Input → View → ViewModel → Model → Services → External APIs/System
     ↑                                      ↓
     └──────── UI Updates ←─────────────────┘
```

### Reactive Programming with Combine

- **@Published** properties in ViewModels trigger UI updates
- **@ObservedObject** and **@StateObject** for view-model binding
- **@Environment** for system state monitoring (scenePhase)

## 🧩 Component Architecture

### Models Layer

- **TimerModel**: Core data structure
  - Configuration properties (minutes, seconds, sets, intensity)
  - Runtime state (current progress, completion flags)
  - Computed properties for calculations

### ViewModels Layer

- **TimerConfigViewModel**: Configuration management
  - Binding wrappers for UI controls
  - Validation logic
  - Factory method for TimerRunViewModel
- **TimerRunViewModel**: Complex timer execution logic
  - Timer state management
  - Background processing coordination
  - Audio and notification scheduling
  - Smart timer preservation for brief app switches

### Views Layer

- **TimerConfigView**: Configuration interface
  - Wheel pickers for time/sets selection
  - Toggle for intensity preference
  - Real-time duration calculation display
- **TimerRunView**: Active workout interface
  - State-indicating circular display
  - Color-coded intensity phases
  - Control buttons (start/pause/reset)
  - ScenePhase monitoring for background transitions

### Services Layer

- **AudioManager**: Singleton for audio operations
  - Sound playback management
  - Speech synthesis
  - Audio session configuration
  - Interruption handling
  - Background audio support
- **NotificationService**: Push notification management
  - Permission requests
  - Notification scheduling with dynamic buffers
  - Background alerts
  - Notification cancellation

## 🔧 Enhanced Background Processing Architecture

### Background Task Management

```
App State Change → TimerRunViewModel.handleScenePhaseChange()
    │
    ├── .inactive → Record timestamp (for brief app switches)
    │
    ├── .background → Record timestamp
    │                 beginBackgroundTask()
    │                 scheduleBackgroundWarnings()
    │                 scheduleCompletionNotification()
    │
    └── .active → Calculate background duration
                  IF duration < minimumBackgroundTime (3.0s)
                  │   └── Preserve existing timer (prevent jumps)
                  │       Update lastTimerFireTime
                  ELSE
                      └── cleanupBackgroundResources()
                          adjustTimerForBackgroundTime()
                          cancelPendingNotifications()
                          Restart timer if needed
```

### Smart Timer Preservation

```
Timer Preservation Strategy:
├── Brief App Switches (<3s): Preserve timer completely
│   ├── If timer exists: Update lastTimerFireTime only
│   └── If timer invalidated: Restart without adjustment
└── Longer Background (≥3s): Full adjustment
    ├── Clean up background resources
    ├── Adjust timer for background time
    └── Restart timer if needed
```

### Timer Firing Compensation

```
Timer Firing Compensation:
IF timeSinceLastFire > 1.5s
    extraSeconds = Int(timeSinceLastFire) - 1
    FOR i in 0..<extraSeconds
        updateTimer() // Catch up missed updates
    END FOR
END IF
updateTimer() // Regular update
```

### Background Warning System

```
Warning Scheduling System:
├── Current Phase Warnings
│   ├── Phase Transition Warning (if not last in set)
│   └── Set Completion Warning (if last in set)
├── Future Phase Calculation
│   ├── Build phase sequence for all future phases
│   └── Calculate time offset for each phase
└── Warning Scheduling
    ├── Schedule warnings for all phases
    └── Create background check timer (0.5s interval)
```

### Warning Playback System

```
Warning Playback System:
├── Check for scheduled warnings
├── Skip if audio already playing
├── For each warning at or past due time:
│   ├── Phase Transition: Play warning sound
│   └── Set Completion:
│       ├── Use current set number from model
│       ├── Check for duplicates (set-based + timestamp-based)
│       ├── Special handling for final set
│       └── Speak announcement if not duplicate
└── Remove played warnings and clean up if done
```

## 🎵 Enhanced Audio Architecture

### Audio Session Management

```
AVAudioSession Configuration:
├── Category: .playback
├── Mode: .default
├── Options: [.mixWithOthers, .duckOthers]
└── Background Capability: Enabled
```

### Audio Components

- **AVAudioPlayer**: For notification sound playback
- **AVSpeechSynthesizer**: For set completion announcements
- **Interruption Handling**: Phone calls, other apps
- **Background Playback**: Continues audio in background

### Audio Timing Strategy

- **Phase Transition Warnings**: Sound plays N seconds before phase end
- **Set Completion Announcements**: Speech synthesis with countdown
- **Background Audio Scheduling**: Pre-calculated warning times

### Multi-Layer Duplicate Prevention

```
Duplicate Prevention Architecture:
├── Set-Based Tracking
│   └── playedSetCompletionWarnings: Set<Int>
├── Timestamp-Based Tracking
│   └── playedSetCompletionWarningsWithTime: [Int: Date]
├── Time-Window Throttling
│   └── Skip if played within last 10 seconds
├── Audio State Checking
│   └── Skip if any audio is already playing
└── Special Final Set Handling
    └── Always play final set warnings
```

### Current State Awareness

```
Current State Awareness:
├── Schedule warnings with set numbers at scheduling time
├── When playing warnings:
│   ├── Get current set number from timer model
│   ├── Use current set for announcement text
│   └── Log if different from scheduled set number
└── Ensures correct set numbers in announcements
```

## 🔔 Enhanced Notification Architecture

### Notification Types

1. **Immediate Notifications**: Workout completion when app is backgrounded
2. **Scheduled Notifications**: Future workout completion alerts
3. **Permission Management**: Request authorization on app launch

### Dynamic Buffer Calculation

```
Buffer Calculation Strategy:
├── Calculate total remaining time
├── Apply dynamic buffer:
│   ├── Short intervals (≤15s): 8-second buffer
│   ├── Longer intervals: 5-second buffer
│   └── Very short intervals (≤10s): Additional proportional buffer
└── Schedule notification with calculated time
```

### Duplicate Prevention

```
Notification Duplicate Prevention:
├── State Tracking
│   └── hasScheduledCompletionNotification flag
├── Scheduled Time Tracking
│   └── scheduledNotificationCompletionTime: Date?
├── Time-Window Throttling
│   └── lastCompletionNotificationTime: Date?
│   └── Skip if sent within last 10 seconds
└── Notification Cancellation
    └── Cancel pending notifications before scheduling new ones
```

### Total Remaining Time Calculation

```
Total Remaining Time Calculation:
├── Current phase remaining time
├── Calculate phases remaining in current set
├── Add time for remaining phases in current set
├── Calculate complete sets remaining
├── Add time for all remaining sets
└── Apply dynamic buffer based on interval duration
```

## 🛠️ Utility Architecture

### Helper Components

- **TimeFormatter**: Consistent time display formatting
- **Computed Properties**: Duration calculations in TimerModel
- **Extension Methods**: Audio and notification delegates

## 🔄 State Management Patterns

### Timer State Machine

```
States: Ready → Running → Paused → Completed
                ↑         ↓
                └─────────┘
```

### Phase Transition Logic

```
Low Intensity Phase → High Intensity Phase → Next Set
        ↑                                        ↓
        └────────── Set Completion ←─────────────┘
```

### Background State Synchronization

- **Timestamp Tracking**: Record state change times
- **Elapsed Time Calculation**: Precise background duration
- **State Reconstruction**: Rebuild timer state from elapsed time
- **Warning State Management**: Track which warnings have been played

## 📝 Documentation Architecture

### Code Documentation

```
Documentation Hierarchy:
├── Class-Level Documentation
│   └── Overview of class purpose and behavior
├── Method Documentation
│   └── Detailed explanations of critical methods
├── Inline Documentation
│   └── Explanations of complex code sections
└── Implementation Notes
    └── Rationale for technical decisions
```

### External Documentation

```
External Documentation:
├── Bug Analysis
│   └── Detailed analysis of bugs and fixes
├── Implementation Guides
│   └── Step-by-step instructions for implementations
├── Line-by-Line Explanations
│   └── Comprehensive explanations of critical functions
└── Memory Bank
    └── Project overview, architecture, features, progress
```

This architecture ensures robust operation across all app states while maintaining clean separation of concerns and testability. The enhanced background processing, audio system, and notification system provide a seamless user experience even during complex app lifecycle transitions.
