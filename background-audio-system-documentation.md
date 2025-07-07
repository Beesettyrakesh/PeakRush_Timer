# PeakRush Timer - Background Audio System Documentation

## Overview

The PeakRush Timer app includes a sophisticated background audio system that enables audio cues to continue playing even when the app is in the background. This document explains how this system works and the recent documentation improvements made to clarify its behavior.

## Key Components

1. **TimerRunViewModel**: Manages the timer state and coordinates background audio playback
2. **AudioManager**: Handles audio session configuration and sound playback
3. **NotificationService**: Manages local notifications for workout completion

## Background Audio Flow

When the app goes into the background while a timer is running, the following sequence occurs:

1. **Scene Phase Change Detection**:
   ```swift
   func handleScenePhaseChange(_ newPhase: ScenePhase) {
       switch newPhase {
           case .background:
               // App went to background
               if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
                   beginBackgroundTask()
                   scheduleBackgroundWarnings()
                   scheduleCompletionNotification()
               }
           // ...
       }
   }
   ```

2. **Background Task Creation**:
   ```swift
   private func beginBackgroundTask() {
       backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
           print("Background task expired")
           self?.endBackgroundTask()
       }
       
       // Configure audio session for background playback
       try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
       
       // Set up periodic audio session refresh
       setupBackgroundAudioRefresh()
   }
   ```

3. **Warning Scheduling**:
   ```swift
   private func scheduleBackgroundWarnings() {
       // Schedule warnings for current phase
       // Schedule warnings for future phases
       
       // Create a timer to check for warnings
       backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
           self?.checkBackgroundWarnings()
       }
   }
   ```

4. **Warning Playback**:
   ```swift
   private func checkBackgroundWarnings() {
       // Check if any warnings should be played
       // Play appropriate warnings (sound or speech)
       // Remove played warnings from the queue
   }
   ```

## Important Design Detail: Current Set Number Usage

A key aspect of the background audio system is how it handles set numbers in warnings:

1. When warnings are scheduled, they include the set number at scheduling time:
   ```swift
   scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, 
                                           type: .setCompletion(setNumber: phase.setNumber)))
   ```

2. However, when warnings are played, they use the current set number from the model:
   ```swift
   case .setCompletion(let setNumber):
       // Use the current set number from the model to ensure accuracy
       let actualSetNumber = timerModel.currentSet
       
       // Use actualSetNumber for the speech announcement
       let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
   ```

This design ensures that even if the timer advances while in the background, the correct set number is announced to the user.

## Duplicate Prevention Mechanisms

The system includes multiple layers of protection against duplicate audio cues:

1. **Set-based tracking**:
   ```swift
   private var playedSetCompletionWarnings: Set<Int> = []
   
   if !playedSetCompletionWarnings.contains(currentSet) {
       playedSetCompletionWarnings.insert(currentSet)
       // Play warning
   }
   ```

2. **Timestamp-based tracking**:
   ```swift
   private var playedSetCompletionWarningsWithTime: [Int: Date] = [:]
   
   if let lastPlayedTime = playedSetCompletionWarningsWithTime[currentSet],
      now.timeIntervalSince(lastPlayedTime) < 10.0 {
       // Skip duplicate warning
   }
   ```

3. **Special handling for final set**:
   ```swift
   let isFinalSet = currentSet == timerModel.sets
   
   if isFinalSet || !playedSetCompletionWarnings.contains(currentSet) {
       // Play warning
   }
   ```

## Documentation Improvements

The following documentation improvements have been made to clarify the background audio system:

1. **Class-level documentation** explaining the overall background audio system:
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
   ```

2. **Warning type documentation** explaining the set number usage:
   ```swift
   // Enum to distinguish between warning types for background mode
   // Note: For setCompletion warnings, the stored setNumber is used only for scheduling.
   // The actual set number announced at playback time is determined by the current timer state.
   private enum WarningType {
       case phaseTransition
       case setCompletion(setNumber: Int)
   }
   ```

3. **Method documentation** for `scheduleBackgroundWarnings()`:
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
   ```

4. **Method documentation** for `checkBackgroundWarnings()`:
   ```swift
   /// Checks if any scheduled warnings should be played and triggers them if appropriate.
   ///
   /// This method is called periodically by the backgroundCheckTimer to check if any
   /// scheduled warnings should be played. When a warning time is reached:
   /// - For phase transitions: A sound is played
   /// - For set completions: A speech announcement is made using the CURRENT set number
   ///   from the timer model, not necessarily the set number that was stored when the
   ///   warning was scheduled. This ensures the announcement matches the actual timer state.
   ```

5. **Inline documentation** for set number handling:
   ```swift
   // Use the current set number from the model to ensure accuracy.
   // Note: This may differ from the 'setNumber' parameter if the timer
   // has advanced while in the background. We prioritize announcing
   // the current timer state rather than what was scheduled.
   let actualSetNumber = timerModel.currentSet
   
   // Log if there's a mismatch between scheduled and actual set numbers
   if setNumber != actualSetNumber {
       print("Note: Set completion was scheduled for set \(setNumber) but playing for current set \(actualSetNumber)")
   }
   ```

6. **Background entry documentation**:
   ```swift
   // Schedule warnings based on current timer state.
   // Note: The timer continues to advance internally while in background,
   // so warnings will be played based on the actual timer state at the time
   // they're triggered, not necessarily what was scheduled here.
   scheduleBackgroundWarnings()
   ```

## Conclusion

The background audio system in PeakRush Timer is designed to provide a seamless user experience with accurate audio cues even when the app is in the background for extended periods. The documentation improvements clarify how the system works, particularly the important detail that set completion announcements use the current timer state rather than what was scheduled.

This approach ensures that users always hear the correct set number in announcements, even if the timer advances while in the background. The multiple layers of duplicate prevention also ensure that users don't hear the same warning multiple times.
