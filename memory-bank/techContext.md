# Technical Context: PeakRush Timer

## Technology Stack

PeakRush Timer is built using the following technologies:

- **Swift 5**: Core programming language
- **SwiftUI**: Modern declarative UI framework for building the interface
- **Foundation**: Base library providing essential data types and utilities
- **AVFoundation**: Framework for audio playback and speech synthesis
- **UserNotifications**: Framework for scheduling and managing local notifications
- **Combine**: (Implicitly used via SwiftUI) Reactive programming framework

## Development Environment

- **Xcode**: Primary IDE for iOS development
- **iOS Target**: iOS 16.0+ for supporting SwiftUI features
- **Swift Package Manager**: Dependency management (if external dependencies are added)
- **Git**: Version control system

## Code Organization

```
PeakRush_Timer/
├── App/                  # App entry points
│   ├── AppDelegate.swift
│   └── PeakRush_TimerApp.swift
├── Models/               # Data structures
│   └── TimerModel.swift
├── ViewModels/           # Business logic
│   ├── TimerConfigViewModel.swift
│   └── TimerRunViewModel.swift
├── Views/                # UI components
│   ├── ContentView.swift
│   ├── TimerConfigView.swift
│   └── TimerRunView.swift
├── Services/             # Shared services
│   ├── AudioManager.swift
│   └── NotificationService.swift
├── Utilities/            # Helper functions
│   └── TimeFormatter.swift
└── Resources/            # Assets and sounds
    ├── notification.mp3
    └── Assets.xcassets/
```

## Key Technical Components

### 1. Timer Management

- Foundation's `Timer` class for time tracking
- Custom time calculation and formatting logic
- State management for timer phases and transitions

### 2. User Interface

- SwiftUI's declarative approach for all UI elements
- Environment properties (`@Environment`) for scene phase detection
- `@Published` and `@ObservedObject` for state observation
- Custom gradient styles and animations for visual feedback

### 3. Audio System

- `AVAudioPlayer` for notification sounds
- `AVSpeechSynthesizer` for spoken announcements
- `AVAudioSession` configuration for background audio support

### 4. Background Execution

- `UIBackgroundTaskIdentifier` for background task management
- Timer adjustment for app state transitions
- Notification scheduling for background alerts

### 5. Local Notifications

- `UNUserNotificationCenter` for scheduling notifications
- Custom notification content and triggers
- Notification management when app returns to foreground

## Technical Constraints

### 1. iOS System Limitations

- **Background Execution**: iOS limits background execution time (typically ~3 minutes)
- **Audio Session Control**: Background audio requires maintaining an active audio session
- **Notification Scheduling**: Local notifications have limits on frequency and quantity

### 2. Device Considerations

- **Battery Usage**: Timer operation and background tasks impact battery life
- **Audio Conflicts**: Other apps may compete for audio resources
- **Notification Permissions**: User must grant permission for local notifications

### 3. Development Constraints

- **SwiftUI Compatibility**: Requires iOS 16+ for full feature support
- **Testing Complexity**: Background mode behavior requires real device testing
- **State Management**: Complex timer states require careful handling of edge cases

## Performance Considerations

1. **Timer Accuracy**:

   - System timers are not perfectly accurate, especially in background mode
   - Time drift compensation is implemented when app returns to foreground

2. **Battery Optimization**:

   - Background task ID management to release system resources when not needed
   - Strategic use of notifications instead of continuous background processing

3. **Audio Performance**:

   - Pre-loading sounds to minimize playback delay
   - Managing audio session to prevent conflicts with other apps

4. **UI Responsiveness**:
   - Lightweight view models to maintain UI performance
   - Minimal view redrawing during timer updates

## Security and Privacy

1. **Data Storage**:

   - No persistent user data stored
   - No network connections required

2. **Permissions**:

   - Notification permissions required for alerting
   - No location or other sensitive permissions needed

3. **Privacy**:
   - No user tracking or analytics implemented
   - Completely offline functionality
