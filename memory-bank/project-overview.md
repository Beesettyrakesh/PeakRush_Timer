# PeakRush Timer - Project Overview

## 📱 Application Summary

**PeakRush Timer** is a sophisticated iOS interval training application built with SwiftUI that enables users to create and execute high/low intensity workout cycles with advanced background processing capabilities and reliable audio cues.

## 🎯 Core Purpose

The app facilitates interval training workouts where users alternate between low and high intensity phases across multiple sets, with audio cues and background operation support, ensuring a seamless experience even when the app is minimized.

## 🏗️ Architecture Pattern

- **Framework**: SwiftUI + Combine
- **Pattern**: MVVM (Model-View-ViewModel)
- **Language**: Swift
- **Platform**: iOS

## 📊 Key Statistics

- **Total Files**: ~15 Swift files
- **Main Components**: 8 core classes/structs
- **Services**: 2 (Audio, Notifications)
- **Views**: 3 main UI components
- **Models**: 1 core data model
- **Documentation Files**: 5 comprehensive guides

## 🚀 Primary Features

1. **Workout Configuration**: Customizable intervals and sets
2. **Timer Execution**: Visual progress with audio cues
3. **Background Processing**: Continues operation when app is backgrounded
4. **Audio Integration**: Sound alerts and speech synthesis
5. **Push Notifications**: Workout completion alerts
6. **Seamless App Switching**: Handles brief app switches without timer jumps

## 🔧 Technical Highlights

- Advanced background task management
- Audio session interruption handling
- Complex state synchronization
- Real-time UI updates with Combine
- Robust error handling and recovery
- Multi-layer duplicate prevention for audio cues
- Smart timer preservation during brief app switches
- Dynamic buffer calculation for notifications

## 📁 Project Structure

```
PeakRush_Timer/
├── App/                    # Application lifecycle
├── Models/                 # Data models
├── Views/                  # SwiftUI views
├── ViewModels/            # Business logic
├── Services/              # External integrations
├── Utilities/             # Helper functions
└── Resources/             # Assets and media
```

## 🎨 User Experience Flow

1. **Setup**: Configure interval duration and number of sets
2. **Validation**: Ensure valid configuration
3. **Execution**: Run timer with visual and audio feedback
4. **Background**: Continue operation when app is minimized
5. **App Switching**: Seamlessly handle brief app switches
6. **Completion**: Notify user when workout is finished

## 💡 Innovation Points

- Seamless background-to-foreground transitions
- Intelligent audio warning scheduling with current state awareness
- Speech synthesis for set completion announcements
- Robust state management across app lifecycle changes
- Smart timer preservation for brief app switches
- Multi-layer duplicate prevention for audio cues and notifications
- Dynamic buffer calculation based on interval duration
- Comprehensive documentation with line-by-line explanations

## 🔄 Recent Improvements

1. **Enhanced Timer Stability**: Fixed timer jumping issues during brief app switches
2. **Improved Audio Reliability**: Implemented multi-layer duplicate prevention for audio cues
3. **Better Notification Timing**: Added dynamic buffer calculation based on interval duration
4. **Comprehensive Documentation**: Added detailed explanations for complex background processing
5. **Resource Management**: Improved cleanup of background resources
