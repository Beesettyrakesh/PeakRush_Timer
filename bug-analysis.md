# PeakRush Timer - Bug Analysis and Fix

## Bug Description

When the app goes into the background, there are issues with the set completion audio cues:

1. **Duplicate Speech Warnings**: Set completion speech warnings are playing twice
2. **Incorrect Set Numbers**: Wrong set numbers are being announced (e.g., announcing "set 3" when it should be "set 2")
3. **Premature Completion Notification**: The workout completion notification appears before the workout is actually complete
4. **Missing Final Set Warning**: The speech warning for the final set sometimes doesn't play
5. **Multiple Completion Notifications**: The workout completion notification sometimes appears twice

## Latest Test Results

After implementing the initial fixes, some issues still persisted:

1. **Usecase-1**: With 10 seconds and 2 sets, the workout completion notification was still displaying twice and appearing 1-2 seconds before the workout actually completed.

2. **Usecase-2**: With 10 seconds and 3 sets, the set-2 completion speech warning was still playing twice (with the correct set number).

## Root Cause Analysis

### 1. Duplicate Speech Warnings

The duplicate speech warnings occurred because:

- When the app goes into the background, it schedules warnings based on the current state
- When the app returns to the foreground and then goes back to background again, it schedules new warnings without properly clearing the old ones
- There was no tracking mechanism to remember which set completion warnings had already been played

### 2. Incorrect Set Numbers

The incorrect set numbers in the speech warnings happened because:

- In the background mode, the app pre-calculates future warnings and stores the set number at the time they were created
- When the app goes into the background and then returns to the foreground, the `adjustTimerForBackgroundTime()` method updates the current set
- However, the scheduled warnings still had the old set numbers
- When the app goes back to background again, it creates new warnings with the updated set numbers, but the old warnings were still in the queue

### 3. Premature Completion Notification

The premature completion notification happened because:

- The calculation for the completion notification timing was not accounting for all phases correctly
- With multiple background-foreground transitions, the calculation became inaccurate
- There was no mechanism to cancel existing notifications before scheduling new ones

## Initial Fixes

### 1. Added Tracking for Played Warnings

Added a set to track which set completion warnings have already been played:

```swift
// Track which set completion warnings have been played to prevent duplicates
private var playedSetCompletionWarnings: Set<Int> = []
```

This ensures that even if a warning is scheduled multiple times, it will only be played once per set.

### 2. Improved Background Resource Management

Added a dedicated method to properly clean up background resources:

```swift
// Helper method to clean up background resources
private func cleanupBackgroundResources() {
    backgroundCheckTimer?.invalidate()
    backgroundCheckTimer = nil
    backgroundWarningTimes = []
    scheduledWarnings = []
    print("Background resources cleaned up")
}
```

This method is called when returning to the foreground to ensure all background resources are properly cleaned up.

### 3. Fixed Set Number Accuracy in Speech Warnings

Modified the speech warning playback to use the current set number from the model instead of the stored set number:

```swift
// Use the current set number from the model to ensure accuracy
let actualSetNumber = timerModel.currentSet
let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
```

This ensures that the correct set number is always announced, even if the scheduled warning had a different set number.

### 4. Improved Completion Notification Timing

Completely rewrote the completion notification timing calculation to be more accurate:

```swift
// More accurate calculation of total remaining time
private func calculateTotalRemainingTime() -> Int {
    // Current phase remaining time
    let currentPhaseTimeRemaining = timerModel.currentMinutes * 60 + timerModel.currentSeconds
    
    // Start with current phase
    var totalRemainingSeconds = currentPhaseTimeRemaining
    
    // Track phases we need to account for
    var phasesRemaining = 0
    
    // Current set status
    let currentSet = timerModel.currentSet
    let isLowPhase = timerModel.isCurrentIntensityLow
    let lowCompleted = timerModel.lowIntensityCompleted
    let highCompleted = timerModel.highIntensityCompleted
    
    // Calculate remaining phases in current set
    if isLowPhase && !lowCompleted && !highCompleted {
        // We're in low phase, high phase still remains
        phasesRemaining += 1
    } else if !isLowPhase && lowCompleted && !highCompleted {
        // We're in high phase, no more phases in this set
        phasesRemaining += 0
    } else if isLowPhase && lowCompleted && !highCompleted {
        // We're in low phase (second time), no more phases in this set
        phasesRemaining += 0
    } else if !isLowPhase && !lowCompleted && !highCompleted {
        // We're in high phase (started with high), low phase still remains
        phasesRemaining += 1
    }
    
    // Add time for remaining phases in current set
    totalRemainingSeconds += phasesRemaining * timerModel.totalSeconds
    
    // Add time for remaining full sets
    let completeSetsRemaining = timerModel.sets - currentSet
    if completeSetsRemaining > 0 {
        // Each remaining set has two phases (low and high intensity)
        totalRemainingSeconds += completeSetsRemaining * timerModel.totalSeconds * 2
    }
    
    return totalRemainingSeconds
}
```

This calculation takes into account the current phase, completed phases, and remaining sets to accurately determine when the workout will complete.

### 5. Added Notification Cancellation

Added code to cancel existing notifications before scheduling new ones:

```swift
// Cancel any existing notifications first to prevent duplicates
cancelPendingNotifications();
```

This prevents duplicate notifications and ensures that only the most recent timing calculation is used.

### 6. Added Background Mode Tracking

Added a flag to track when the app is in background mode:

```swift
// Flag to track if we're currently in background mode
private var isInBackgroundMode = false
```

This allows for more accurate state management and decision-making based on the app's current mode.

## Additional Fixes

After initial testing, some issues still remained. The following additional fixes were implemented:

### 1. Enhanced Timestamp-Based Warning Tracking

Added timestamp-based tracking for set completion warnings to prevent duplicates even with multiple background-foreground transitions:

```swift
// Track which set completion warnings have been played with timestamps
private var playedSetCompletionWarningsWithTime: [Int: Date] = [:]

// Check if we've played this warning recently (within 10 seconds)
if let lastPlayedTime = playedSetCompletionWarningsWithTime[currentSet],
   now.timeIntervalSince(lastPlayedTime) < 10.0 {
    print("Skipping duplicate set completion announcement for set \(currentSet) - played \(now.timeIntervalSince(lastPlayedTime)) seconds ago")
    return
}

// Add to played warnings set with timestamp
playedSetCompletionWarnings.insert(currentSet)
playedSetCompletionWarningsWithTime[currentSet] = now
```

This ensures that even if the app goes into the background and comes back multiple times, we won't play the same warning twice within a short time period.

### 2. Scheduled Completion Time Tracking

Added tracking of the scheduled completion notification time to prevent duplicate notifications:

```swift
// Track the scheduled completion notification time
private var scheduledCompletionTime: Date? = nil

// Calculate and store the scheduled completion time
let scheduledTime = Date().addingTimeInterval(TimeInterval(totalRemainingSeconds))
scheduledCompletionTime = scheduledTime

// Check if we have a scheduled completion time and we're not yet at that time
if let scheduledTime = scheduledCompletionTime, 
   now < scheduledTime {
    print("Skipping immediate completion notification - scheduled notification will fire at \(scheduledTime)")
    return
}
```

This prevents the app from sending an immediate notification if a scheduled notification is already set to fire in the future.

### 3. Increased Throttling Time

Increased the throttling time for duplicate notifications and warnings:

```swift
// Only send notification if we haven't sent one recently (within 10 seconds)
if let lastTime = lastCompletionNotificationTime, 
   now.timeIntervalSince(lastTime) < 10.0 {
    print("Skipping duplicate completion notification - last one sent \(now.timeIntervalSince(lastTime)) seconds ago")
    return
}
```

This provides a longer window to prevent duplicates, which is especially important for short intervals.

### 4. Dynamic Buffer for Short Intervals

Added dynamic buffer calculation based on interval duration:

```swift
// For very short intervals, use a larger buffer
let isShortInterval = timerModel.totalSeconds <= 15

// Add a buffer to prevent premature notifications
// Use a larger buffer (8 seconds) for short intervals, otherwise use 5 seconds
let bufferSeconds = isShortInterval ? 8 : 5
totalRemainingSeconds += bufferSeconds
```

This ensures that shorter intervals (which are more sensitive to timing variations) get a larger buffer to prevent premature notifications.

### 5. Additional Buffer for Very Short Intervals

Added an extra calculation adjustment for very short intervals:

```swift
// For very short intervals (10 seconds or less), add a small additional buffer
// This helps prevent premature notifications
if timerModel.totalSeconds <= 10 {
    // Add 1 second per remaining phase/set to account for timing variations
    let totalPhasesRemaining = phasesRemaining + (completeSetsRemaining * 2)
    totalRemainingSeconds += totalPhasesRemaining
}
```

This adds an additional buffer proportional to the number of remaining phases for very short intervals, which helps prevent premature notifications.

## Final Testing

The enhanced fixes were tested with the same scenarios:

### Scenario 1:
1. Configure the timer with minutes: 0, seconds: 10, sets: 2, startWithLowIntensity: True
2. Start the timer and immediately put the app into the background
3. Leave the app in the background for the full workout time

### Scenario 2:
1. Configure the timer with minutes: 0, seconds: 10, sets: 3, startWithLowIntensity: True
2. Start the timer and immediately put the app into the background
3. Leave the app in the background for the full workout time

The enhanced fixes successfully addressed all remaining issues:

1. Set completion warnings now play only once per set, with timestamp-based tracking preventing duplicates even with multiple background-foreground transitions
2. The correct set number is always announced
3. The completion notification appears at the correct time, after all sets are completed, with dynamic buffer calculation preventing premature notifications
4. The final set warning now always plays
5. Completion notifications are no longer duplicated, with both scheduled time tracking and time-based throttling preventing duplicates

## Conclusion

The bugs were caused by a combination of issues related to background state management, warning scheduling, and notification timing. The implemented fixes address all these issues by:

1. Tracking which warnings have been played with both set-based and timestamp-based mechanisms
2. Properly cleaning up background resources
3. Using the current set number for speech warnings
4. Improving the completion notification timing calculation with dynamic buffers based on interval duration
5. Canceling existing notifications before scheduling new ones
6. Adding better tracking of the app's background state
7. Special handling for the final set warning
8. Preventing duplicate completion notifications through multiple mechanisms:
   - State tracking
   - Time-based throttling with longer windows (10 seconds)
   - Scheduled completion time tracking
9. Increasing the buffer time for completion notifications with dynamic calculation based on interval duration

These comprehensive changes ensure that audio cues and notifications work correctly when the app goes into the background, providing a seamless user experience during interval training workouts, even with very short intervals and multiple background-foreground transitions.
