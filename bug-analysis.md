# Timer Jumping Bug Analysis

## Issue Description

When the PeakRush Timer app is running and you briefly switch to another app and back, the timer jumps ahead by more seconds than the actual time spent away from the app.

## Root Cause

After analyzing the code, I've identified the issue in the `TimerRunViewModel.handleScenePhaseChange()` method. The problem has two main components:

1. **Timer Restart Logic**: When returning to the foreground, the app is stopping and restarting the timer, which can cause timing inconsistencies.

2. **Minimum Background Time Threshold**: The app has a `minimumBackgroundTime` threshold (currently set to 1.0 seconds) that determines whether to adjust the timer for background time. However, the implementation has a flaw in how it handles very brief app switches.

Here's the problematic code section in `handleScenePhaseChange()`:

```swift
case .active:
    // App came to foreground
    if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
        // Calculate how long the app was in background
        let backgroundDuration = now.timeIntervalSince(lastStateChangeTime)

        // Only process background time if the app was in background for a meaningful duration
        if backgroundDuration >= minimumBackgroundTime {
            // Stop background timer if it exists
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
            backgroundWarningTimes = []
            scheduledWarnings = []

            adjustTimerForBackgroundTime()
            cancelPendingNotifications()
        }

        // Restart the timer if it's still supposed to be running
        if !timerModel.isTimerCompleted && timerModel.currentSet <= timerModel.sets {
            startTimer()
        }
    }
```

The issue is that the timer is always restarted with `startTimer()` regardless of how brief the background duration was, but the time adjustment only happens if the background duration exceeds the minimum threshold. This creates a mismatch between the actual elapsed time and the timer's state.

Additionally, in the `startTimer()` method, there's this check:

```swift
// If we already have a timer running, don't create a new one
// This prevents timer jumps during brief state changes
if timer != nil && timerModel.isTimerRunning {
    print("Timer already running, not restarting")
    return
}
```

However, this check might not be working as intended because the timer is invalidated when going to the background.

## Solution

Here's how to fix the issue:

1. **Modify the `handleScenePhaseChange()` method** to be more intelligent about timer restarts for brief background durations:

```swift
case .active:
    // App came to foreground
    if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
        // Calculate how long the app was in background
        let backgroundDuration = now.timeIntervalSince(lastStateChangeTime)

        if backgroundDuration < minimumBackgroundTime {
            // For very brief background durations, don't restart the timer if it's still valid
            if timer != nil {
                print("Brief background duration (\(backgroundDuration)s), keeping existing timer")
                return
            } else {
                // If timer was invalidated, restart it without adjusting time
                print("Brief background duration but timer was invalidated, restarting without adjustment")
                startTimer()
            }
        } else {
            // For longer background durations, perform full adjustment
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
            backgroundWarningTimes = []
            scheduledWarnings = []

            adjustTimerForBackgroundTime()
            cancelPendingNotifications()

            // Restart the timer if it's still supposed to be running
            if !timerModel.isTimerCompleted && timerModel.currentSet <= timerModel.sets {
                startTimer()
            }
        }
    }
```

2. **Modify the background handling in `handleScenePhaseChange()`** to not invalidate the timer for very brief transitions:

```swift
case .background:
    // Record the time we entered background
    lastStateChangeTime = now

    // App went to background
    if timerModel.isTimerRunning && !timerModel.isTimerCompleted {
        // Don't immediately invalidate the timer - we'll do that if needed when returning to foreground
        // This helps with brief app switches

        beginBackgroundTask()
        scheduleBackgroundWarnings()

        // Only schedule completion notification
        scheduleCompletionNotification()
    }
```

3. **Increase the `minimumBackgroundTime` threshold** to better handle brief app switches:

```swift
private var minimumBackgroundTime: TimeInterval = 2.0 // Increased from 1.0
```

## Testing the Fix

After implementing these changes, test the app with the following scenarios:

1. **Very Brief App Switch**: Switch to another app and back within 1-2 seconds. The timer should continue with minimal or no jumping.

2. **Medium Duration Background**: Put the app in the background for 5-10 seconds. The timer should adjust correctly.

3. **Long Background Duration**: Keep the app in the background for several minutes. The timer should adjust correctly when you return.

Monitor the console logs to verify the correct code path is being taken based on the background duration.
