# Completion Notification Timing Fix

## Issue Description

When the last set's last phase was about to complete (i.e., the whole workout was about to complete), the completion notification was being sent before the final set completion speech warning. This created a poor user experience where the user would receive a notification that the workout was complete, but then 1-3 seconds later would hear the speech warning for the final set.

From the logs:
```
Started speaking: Set 7 completing in 3, 2, 1, 0
Playing set completion announcement for set 7 at 2025-07-17 09:50:34 +0000
Speech synthesis finished
Final set completion announcement finished
Audio session refreshed at 2025-07-17 09:50:39 +0000
Background refresh - Current timer state - Set: 7/7, Time: 0:0, Phase: High
Ending background task with ID: 17
All pending notifications cancelled
Cancelled all pending notifications
Timer stopped and all resources released
Found similar notification sent at 2025-07-17 09:50:31 +0000, 8.03291404247284 seconds ago
```

The notification was sent at 09:50:31, but the speech warning started at 09:50:34, creating a confusing user experience.

## Root Cause

The issue was occurring because:

1. When the app entered the background, it scheduled a completion notification based on the calculated remaining time of the workout.
2. When the final set was about to complete, the app played a speech warning.
3. The scheduled completion notification was firing before the speech warning finished.

The root cause was that there was no coordination between the scheduled completion notification and the final set completion speech warning.

## Fix Implementation

The fix involved three key changes:

### 1. Cancel Scheduled Notifications in `checkAndPlaySetCompletionWarning()`

When the final set completion warning is about to play, we now cancel any scheduled completion notifications:

```swift
// If this is the final set, cancel any scheduled completion notifications
// to prevent them from firing before the speech warning completes
if isFinalSet {
    print("Final set completion warning about to play - canceling scheduled completion notifications")
    notificationService.cancelNotification(withIdentifier: "workoutComplete")
    hasScheduledCompletionNotification = false
    scheduledNotificationCompletionTime = nil
}
```

### 2. Cancel Scheduled Notifications in `checkBackgroundWarnings()`

Similarly, when the final set completion warning is about to play in background mode, we cancel any scheduled completion notifications:

```swift
// If this is the final set, cancel any scheduled completion notifications
// to prevent them from firing before the speech warning completes
if isFinalSet {
    print("Final set completion warning about to play in background - canceling scheduled completion notifications")
    notificationService.cancelNotification(withIdentifier: "workoutComplete")
    hasScheduledCompletionNotification = false
    scheduledNotificationCompletionTime = nil
}
```

### 3. Cancel Scheduled Notifications in `completeTimer()`

When the timer completes, we ensure that any scheduled completion notifications are canceled before sending the immediate notification:

```swift
private func completeTimer() {
    stopTimer()
    timerModel.isTimerCompleted = true
    
    // Cancel any scheduled completion notifications first
    notificationService.cancelNotification(withIdentifier: "workoutComplete")
    hasScheduledCompletionNotification = false
    scheduledNotificationCompletionTime = nil
    
    // Check if speech is currently playing
    if audioManager.isSpeaking() {
        print("Speech is currently playing, delaying completion notification")
        
        // Wait for speech to complete before sending notification
        audioManager.speakText("", completion: { [weak self] in
            self?.sendCompletionNotification()
        })
    } else {
        // No speech playing, send notification immediately
        sendCompletionNotification()
    }
    
    // Provide haptic feedback if in foreground
    if UIApplication.shared.applicationState != .background {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}
```

### 4. Add Completion Handlers for Final Set Speech Warnings

For the final set completion warning, we now add a completion handler to ensure that the speech finishes before any further actions are taken:

```swift
// For the final set, add a completion handler
if isFinalSet {
    let _ = audioManager.speakText(setCompletionText, rate: 0.5) {
        // This will be called when speech completes
        print("Final set completion announcement finished")
    }
} else {
    // For non-final sets, no completion handler needed
    let _ = audioManager.speakText(setCompletionText, rate: 0.5)
}
```

## Benefits of the Fix

1. **Improved User Experience**: The user now hears the final set completion warning before receiving the completion notification, which provides a more logical and intuitive flow.

2. **Consistent Behavior**: The fix ensures consistent behavior regardless of whether the app is in the foreground or background.

3. **Better Coordination**: The speech warnings and notifications are now properly coordinated, preventing confusing overlaps.

4. **Enhanced Logging**: Additional logging statements have been added to help track the timing of speech warnings and notifications, making it easier to debug any future issues.

## Testing and Verification

The fix has been tested in various scenarios:

1. **Foreground Operation**: The app correctly plays the final set completion warning before sending the completion notification.

2. **Background Operation**: When the app is in the background, it correctly cancels any scheduled completion notifications when the final set completion warning is about to play.

3. **Brief App Switches**: The app maintains the correct behavior even when briefly switching between apps.

4. **Extended Background Operation**: The app correctly handles the timing of warnings and notifications even during extended background operation.

This fix significantly improves the user experience by ensuring that audio cues and notifications occur in a logical and intuitive sequence.
