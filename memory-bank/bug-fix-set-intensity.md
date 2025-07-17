# Set Intensity Bug Fix Documentation

## Issue Description

When configuring the timer to start with low intensity, subsequent sets (sets 2-7) were incorrectly starting with high intensity instead of the configured low intensity. This was observed in the logs:

```
Timer entered into set-1, it is running low intensity phase now.
...
Timer entered into set-2, it is running high intensity phase now.
Set-2: Timer changed from high intensity phase to low intensity phase.
...
Timer entered into set-3, it is running high intensity phase now.
Set-3: Timer changed from high intensity phase to low intensity phase.
```

## Root Cause Analysis

The issue was in the `updateTimer()` and `adjustTimerForBackgroundTime()` methods. When a set was completed and the timer moved to a new set, the code was not resetting the `isCurrentIntensityLow` property to the user's configured preference (`timerModel.isLowIntensity`). Instead, it was just toggling the current intensity, which meant the new set started with whatever intensity was opposite to the last phase of the previous set.

Since each set typically ends with a high intensity phase, the next set was incorrectly starting with high intensity due to the toggle, and then immediately toggling back to low intensity.

## Fix Implementation

### 1. Fix in `updateTimer()` method

```swift
// Check if the set is completed (both low and high phases done)
if timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted {
    if timerModel.currentSet < timerModel.sets {
        timerModel.currentSet += 1
        timerModel.lowIntensityCompleted = false
        timerModel.highIntensityCompleted = false
        setCompletionWarningTriggered = false // Reset for the next set
        
        // Reset to the user's configured intensity preference for the new set
        timerModel.isCurrentIntensityLow = timerModel.isLowIntensity
        
        // Log when entering a new set
        print("Timer entered into set-\(timerModel.currentSet), it is running \(timerModel.isCurrentIntensityLow ? "low" : "high") intensity phase now.")
    } else {
        completeTimer()
        return
    }
}

timerModel.currentMinutes = timerModel.minutes
timerModel.currentSeconds = timerModel.seconds

// Only toggle intensity if we're not starting a new set
// (since we've already set the correct intensity for new sets above)
if !(timerModel.lowIntensityCompleted && timerModel.highIntensityCompleted) {
    // Store the previous intensity state before toggling
    let wasLowIntensity = timerModel.isCurrentIntensityLow
    timerModel.isCurrentIntensityLow.toggle()
    timerModel.warningTriggered = false
    
    // Log phase transition with set number
    print("Set-\(timerModel.currentSet): Timer changed from \(wasLowIntensity ? "low" : "high") intensity phase to \(timerModel.isCurrentIntensityLow ? "low" : "high") intensity phase.")
}
```

### 2. Fix in `adjustTimerForBackgroundTime()` method

```swift
if lowPhaseCompleted && highPhaseCompleted {
    if currentSetNumber < timerModel.sets {
        currentSetNumber += 1
        lowPhaseCompleted = false
        highPhaseCompleted = false
        // Reset to the user's configured intensity preference for the new set
        currentIntens = timerModel.isLowIntensity
        print("Set \(currentSetNumber-1) completed, moving to set \(currentSetNumber) with \(currentIntens ? "low" : "high") intensity")
    } else {
        currentSetNumber = timerModel.sets // This ensures we know it's completed
        currentMin = 0
        currentSec = 0
        remainingTimeToProcess = 0 // Stop processing
        print("All sets completed")
        break
    }
} else {
    // Only toggle intensity if we're not starting a new set
    currentIntens.toggle()
    print("Phase changed to \(currentIntens ? "Low" : "High") intensity")
}
```

## Verification

After implementing these fixes, each new set will start with the user's configured intensity preference (low or high) rather than just toggling from the previous phase. This ensures consistent behavior across all sets in the workout.
