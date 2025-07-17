# PeakRush Timer - Bug Fixes Documentation

This document provides detailed information about the bugs that were identified and fixed in the PeakRush Timer app.

## 8. Compiler Warnings and Errors

### Issue Description
Several compiler warnings and errors were identified in the AudioManager.swift and TimerRunViewModel.swift files:

1. In AudioManager.swift:
   - Warning: 'catch' block is unreachable because no errors are thrown in 'do' block
   - Warning: Constant 'isActive' inferred to have type '()', which may be unexpected
   - Error: Cannot convert return expression of type '()' to return type 'Bool'

2. In TimerRunViewModel.swift:
   - Error: Cannot convert value of type '()' to expected condition type 'Bool'

These issues were preventing the app from compiling and running properly.

### Root Cause
1. In AudioManager.swift:
   - The `isAudioSessionHealthy()` method had a try-catch block around code that doesn't throw any errors. The property `isOtherAudioPlaying` is a Boolean property that doesn't throw errors.
   - The `ensureAudioSessionActive()` method was trying to assign the return value of `setActive()` to a variable and then return that variable as a Boolean. However, `setActive()` returns Void, not a Boolean.

2. In TimerRunViewModel.swift:
   - The `playWarningSound()` method was being used in a conditional statement (`if playWarningSound() { ... }`), but it didn't return a Boolean value.

### Fix Implementation
1. In AudioManager.swift:
   - Removed the unnecessary try-catch block in `isAudioSessionHealthy()`:
     ```swift
     // Before:
     do {
         let isActive = AVAudioSession.sharedInstance().isOtherAudioPlaying == false
         return isActive
     } catch {
         print("Error checking audio session health: \(error)")
         return false
     }
     
     // After:
     let isActive = AVAudioSession.sharedInstance().isOtherAudioPlaying == false
     return isActive
     ```

   - Fixed the return value in `ensureAudioSessionActive()`:
     ```swift
     // Before:
     do {
         let isActive = try AVAudioSession.sharedInstance().setActive(true)
         lastAudioSessionActivationTime = Date()
         return isActive
     } catch {
         print("Failed to activate audio session even after reset: \(error)")
         return false
     }
     
     // After:
     do {
         try AVAudioSession.sharedInstance().setActive(true)
         lastAudioSessionActivationTime = Date()
         return true  // If no exception is thrown, activation was successful
     } catch {
         print("Failed to activate audio session even after reset: \(error)")
         return false
     }
     ```

2. In TimerRunViewModel.swift:
   - Modified the `playWarningSound()` method to return a Boolean value:
     ```swift
     // Before:
     private func playWarningSound() {
         // Only set the flag and play if not already playing
         if !audioManager.isPlaying() && !audioManager.isSpeaking() {
             timerModel.warningTriggered = true
             
             // Play the sound using AudioManager
             let success = audioManager.playSound()
             
             if success {
                 print("Warning sound played for phase transition in set \(timerModel.currentSet)")
             } else {
                 print("Failed to play warning sound for phase transition in set \(timerModel.currentSet)")
             }
         }
     }
     
     // After:
     private func playWarningSound() -> Bool {
         // Only set the flag and play if not already playing
         if !audioManager.isPlaying() && !audioManager.isSpeaking() {
             timerModel.warningTriggered = true
             
             // Play the sound using AudioManager
             let success = audioManager.playSound()
             
             if success {
                 print("Warning sound played for phase transition in set \(timerModel.currentSet)")
                 return true
             } else {
                 print("Failed to play warning sound for phase transition in set \(timerModel.currentSet)")
                 return false
             }
         }
         
         // Return false if audio is already playing
         return false
     }
     ```

### Testing and Verification
The fixes were tested and verified to work correctly. The app now compiles without warnings or errors, and the affected functionality works as expected:

1. The `isAudioSessionHealthy()` method correctly checks if other audio is playing.
2. The `ensureAudioSessionActive()` method correctly activates the audio session and returns a Boolean indicating success.
3. The `playWarningSound()` method correctly returns a Boolean indicating whether the sound was played successfully, which allows it to be used in conditional statements.

These fixes improve the code quality and ensure that the app behaves correctly in all scenarios.

## 6. Completion Notification Timing Issue

### Issue Description
When the last set's last phase was about to complete (i.e., the whole workout was about to complete), the completion notification was being sent before the final set completion speech warning. This created a poor user experience where the user would receive a notification that the workout was complete, but then 1-3 seconds later would hear the speech warning for the final set.

### Root Cause
The issue was occurring because:

1. When the app entered the background, it scheduled a completion notification based on the calculated remaining time of the workout.
2. When the final set was about to complete, the app played a speech warning.
3. The scheduled completion notification was firing before the speech warning finished.

The root cause was that there was no coordination between the scheduled completion notification and the final set completion speech warning.

### Fix Implementation
The fix involved three key changes:

1. Cancel scheduled notifications in `checkAndPlaySetCompletionWarning()` when the final set completion warning is about to play
2. Cancel scheduled notifications in `checkBackgroundWarnings()` when the final set completion warning is about to play in background mode
3. Cancel scheduled notifications in `completeTimer()` before sending the immediate notification
4. Add completion handlers for final set speech warnings to ensure that the speech finishes before any further actions are taken

For more details, see [completion-notification-timing-fix.md](completion-notification-timing-fix.md).

## 7. Delayed Log Printing Issue

### Issue Description
After phase transition warnings or set completion warnings were played, there was a delay between when the audio warnings played and when the corresponding phase/set transition logs appeared. For example, after hearing "Set 4 completing in 3, 2, 1, 0", the log statement `***ENTERED INTO SET-5: Running in low intensity phase now.***` wouldn't appear immediately but would take 2-3 seconds to print.

### Root Cause
The issue was due to the timer update logic. The audio warnings were scheduled based on time, but the actual phase/set transitions happened in the `updateTimer()` method which runs on a 1-second interval. This created a timing mismatch between:

1. When the warning was played (based on the scheduled warning time)
2. When the actual phase/set transition occurred (based on the timer update interval)

The warnings were played when the timer reached a certain threshold (e.g., 5 seconds remaining), but the actual phase/set transition only occurred when the timer reached 0 seconds, which happened a few seconds later.

### Fix Implementation
We implemented a predictive logging solution that prints a prediction message when the warning is played, but notes that it's a prediction:

1. Added predictive logging to `checkAndPlaySetCompletionWarning()` for foreground operation:
   ```swift
   // Print predictive log to help with debugging
   if currentSet < timerModel.sets {
       // Next set will start with the user's configured intensity preference
       print("***PREDICTING TRANSITION TO SET-\(currentSet + 1): Will be running in \(timerModel.isLowIntensity ? "low" : "high") intensity phase in \(setCompletionWarningSeconds) seconds***")
   } else {
       // Final set completion
       print("***PREDICTING WORKOUT COMPLETION in \(setCompletionWarningSeconds) seconds***")
   }
   ```

2. Added similar predictive logging to `checkBackgroundWarnings()` for background operation.

This solution provides immediate feedback when warnings are played without disrupting the timer's natural rhythm, and clearly distinguishes between predictions and actual transitions.

For more details, see [delayed-log-printing-issue.md](delayed-log-printing-issue.md).

## 1. Phase Transition Inconsistency

### Issue Description
When a set was completed and the timer moved to a new set, subsequent sets (sets 2-7) were incorrectly starting with high intensity instead of the configured low intensity preference. This was observed in the logs:

```
Timer entered into set-1, it is running low intensity phase now.
...
Timer entered into set-2, it is running high intensity phase now.
Set-2: Timer changed from high intensity phase to low intensity phase.
...
Timer entered into set-3, it is running high intensity phase now.
Set-3: Timer changed from high intensity phase to low intensity phase.
```

### Root Cause
The issue was in the `updateTimer()` and `adjustTimerForBackgroundTime()` methods. When a set was completed and the timer moved to a new set, the code was not resetting the `isCurrentIntensityLow` property to the user's configured preference (`timerModel.isLowIntensity`). Instead, it was just toggling the current intensity, which meant the new set started with whatever intensity was opposite to the last phase of the previous set.

Since each set typically ends with a high intensity phase, the next set was incorrectly starting with high intensity due to the toggle, and then immediately toggling back to low intensity.

### Fix Implementation
1. In the `updateTimer()` method:
   - Added a return statement after setting up a new set to prevent the phase toggle logic from executing
   - Reset the intensity to the user's configured preference when starting a new set

2. In the `adjustTimerForBackgroundTime()` method:
   - Added a continue statement to skip to the next iteration after setting up a new set
   - Reset the intensity to the user's configured preference when starting a new set

## 2. Warning Schedule Mismatch

### Issue Description
The background warning system was scheduling warnings with incorrect set numbers, which caused a mismatch between the scheduled set number and the actual set number at playback time. This was observed in the logs:

```
Scheduled set completion warning for set-3 at 2025-07-17 07:49:27 +0000
...
Note: Set completion was scheduled for set 3 but playing for current set 2
```

### Root Cause
The issue was in the `scheduleBackgroundWarnings()` method where the phase sequence generation logic was incorrectly calculating the next set number.

### Fix Implementation
1. Modified the phase sequence generation logic in the `scheduleBackgroundWarnings()` method:
   - Used the correct set number for scheduling (the actual set number, not +1)
   - Added more detailed logging to track the scheduled phases for each set
   - Ensured the first phase of each set uses the user's configured intensity preference

## 3. Audio Server Connection Issue

### Issue Description
The app was experiencing IPC client connection errors with the audio server during extended background operation:

```
IPCAUClient.cpp:139   IPCAUClient: can't connect to server (-66748)
```

This could cause audio playback failures during long workouts.

### Root Cause
The audio session was losing its connection to the system audio server during extended background operation.

### Fix Implementation
1. Added a `recoverAudioSession()` method to the AudioManager class:
   - Implemented a sophisticated recovery mechanism that tries different audio session categories and modes
   - Added a delay to allow system resources to reset before attempting recovery
   - Added fallback mechanisms if the initial recovery attempts fail

2. Enhanced the `speakText()` method to use the recovery mechanism:
   - Added a call to `recoverAudioSession()` when audio session activation fails
   - Added special handling for empty text with completion handlers

3. Added voice service caching to improve reliability:
   - Implemented a `cachedVoice` property to avoid repeated lookups
   - Added a `getVoice()` method with multiple fallback mechanisms
   - Improved error handling for voice service failures

## 4. Voice Services Errors

### Issue Description
The app was experiencing voice service query failures:

```
Query for com.apple.MobileAsset.VoiceServicesVocalizerVoice failed: 2
#FactoryInstall Unable to query results, error: 5
Query for com.apple.MobileAsset.VoiceServices.GryphonVoice failed: 2
```

### Root Cause
The voice service initialization was failing due to system-level issues.

### Fix Implementation
1. Implemented voice service caching:
   - Added a `cachedVoice` property to avoid repeated lookups
   - Created a `getVoice()` method with multiple fallback mechanisms:
     - First tries to use the cached voice
     - Then tries to get a voice for the preferred language
     - Falls back to any available voice
     - As a last resort, creates a basic voice

2. Enhanced error handling for speech synthesis:
   - Added special handling for empty text with completion handlers
   - Improved the retry mechanism for speech synthesis failures

## 5. RenderBox Framework Error

### Issue Description
The app was experiencing RenderBox framework errors:

```
Unable to open mach-O at path: /Library/Caches/com.apple.xbs/Binaries/RenderBox/install/Root/System/Library/PrivateFrameworks/RenderBox.framework/default.metallib  Error:2
```

### Root Cause
This is a system-level error related to the Metal graphics framework. It doesn't affect the app's functionality but clutters the console output.

### Fix Implementation
1. Created a `MetalErrorLogger` class to monitor and log Metal framework errors:
   - Implemented a singleton pattern for easy access
   - Added methods to start and stop monitoring
   - Added handlers for potential Metal errors
   - Added a method to log RenderBox framework errors

2. Updated the AppDelegate to initialize the MetalErrorLogger:
   - Added a call to `MetalErrorLogger.shared.startMonitoring()` in the `application(_:didFinishLaunchingWithOptions:)` method

## Testing and Verification

All fixes have been tested and verified to work correctly. The app now:

1. Correctly starts each new set with the user's configured intensity preference
2. Correctly schedules and plays warnings with the appropriate set numbers
3. Recovers from audio session failures during extended background operation
4. Handles voice service failures gracefully with multiple fallback mechanisms
5. Logs RenderBox framework errors without affecting the app's functionality

These fixes significantly improve the reliability and user experience of the PeakRush Timer app, particularly during extended background operation.

## Newly Identified Issues

Recent testing with longer workouts (12 sets) has revealed several additional issues that need to be addressed:

### 1. Audio Playback Failure in Long Workouts

During extended background operation with longer workouts (12+ sets), the app fails to play warning sounds for later sets:

```
Failed to play warning sound (attempt 1)
Failed to play warning sound (attempt 2)
Failed to play warning sound (attempt 3)
Failed to play warning sound after multiple attempts
Failed to play warning sound for phase transition in set 12
```

This is likely due to iOS reclaiming audio resources after prolonged background execution.

### 2. Background Task Expiration

During longer workouts, background tasks expire despite the renewal system:

```
Renewed background task expired
Background task expiring, attempting renewal
Renewed background task with ID: 41
Ending background task with ID: 41
```

This affects audio playback and notifications during extended background operation.

### 3. Speech Interruption

Speech synthesis is interrupted during longer workouts:

```
Speech stopped
```

Instead of the expected "Speech synthesis finished" message, suggesting that the speech synthesis is being interrupted.

### 4. Missing Phase Transition Warning for Set 2

In both test cases, there's no scheduled phase transition warning for set 2:

```
Scheduled phase transition for current set-1, warning at 2025-07-17 13:59:13 +0000
Scheduled phases for set 3: Low followed by High
```

The phase sequence generation logic in `scheduleBackgroundWarnings()` is skipping set 2.

### 5. Inconsistent Warning Playback Timing

In some cases, warnings are played at unexpected times:

```
Warning sound started playing successfully
Warning sound played for phase transition in set 9
Renewed background task with ID: 36
Background refresh - Current timer state - Set: 9/12, Time: 0:3, Phase: Low
```

The phase transition warning for set 9 is played when there are still 3 seconds remaining, not at the expected 5-second mark.

### 6. Notification Timing Issue

Despite our fix for the completion notification timing issue, there's still a case where the notification is sent before the speech warning completes:

```
Found similar notification sent at 2025-07-17 14:07:03 +0000, 18.394009947776794 seconds ago
```

### 7. Minor Log Issues

Several minor issues were identified:

1. Typo in log messages: "TRNASITION" should be "TRANSITION"
2. Inconsistent log formatting
3. Redundant log messages

A detailed analysis and implementation plan for these issues has been documented in [extended-background-operation-issues.md](extended-background-operation-issues.md).
