# PeakRush Timer - Technical Architecture

## 🏗️ MVVM Architecture Overview

The PeakRush Timer follows a clean MVVM (Model-View-ViewModel) architecture pattern with clear separation of concerns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Views       │◄──►│   ViewModels    │◄──►│     Models      │
│   (SwiftUI)     │    │  (ObservableObject) │    │   (Structs)     │
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

### Views Layer

- **TimerConfigView**: Configuration interface
  - Wheel pickers for time/sets selection
  - Toggle for intensity preference
  - Real-time duration calculation display
- **TimerRunView**: Active workout interface
  - Circular progress indicator
  - Color-coded intensity phases
  - Control buttons (start/pause/reset)

### Services Layer

- **AudioManager**: Singleton for audio operations
  - Sound playback management
  - Speech synthesis
  - Audio session configuration
  - Interruption handling
- **NotificationService**: Push notification management
  - Permission requests
  - Notification scheduling
  - Background alerts

## 🔧 Background Processing Architecture

### Background Task Management

```
App State Change → TimerRunViewModel.handleScenePhaseChange()
                        ├── .background → beginBackgroundTask()
                        │                 ├── scheduleBackgroundWarnings()
                        │                 └── scheduleCompletionNotification()
                        └── .active → adjustTimerForBackgroundTime()
                                     └── cancelPendingNotifications()
```

### Background Timer Strategy

1. **Foreground**: Standard Timer with 1-second intervals
2. **Background**:
   - Pause active timer
   - Schedule audio warnings based on calculated times
   - Use background task identifier for extended execution
   - Schedule push notifications for completion

### State Synchronization

- **Time Adjustment Algorithm**: Calculates elapsed background time
- **Warning Scheduling**: Pre-calculates all future warning times
- **State Recovery**: Reconstructs timer state when returning to foreground

## 🎵 Audio Architecture

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

## 🔔 Notification Architecture

### Notification Types

1. **Immediate Notifications**: Workout completion when app is backgrounded
2. **Scheduled Notifications**: Future workout completion alerts
3. **Permission Management**: Request authorization on app launch

### Background Notification Strategy

- Calculate total remaining workout time
- Schedule single completion notification
- Cancel notifications when returning to foreground
- Handle permission states gracefully

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

This architecture ensures robust operation across all app states while maintaining clean separation of concerns and testability.
