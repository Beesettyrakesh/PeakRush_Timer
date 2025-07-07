# Line-by-Line Explanation of `checkBackgroundWarnings()` Function

The `checkBackgroundWarnings()` function is a critical part of the background audio system in the PeakRush Timer app. It's responsible for checking if any scheduled warnings should be played and triggering them at the appropriate time. Here's a detailed explanation of each line:

```swift
private func checkBackgroundWarnings() {
```
This line defines a private function named `checkBackgroundWarnings()` that can only be called from within the `TimerRunViewModel` class.

```swift
print("Current set: \(timerModel.currentSet)/\(timerModel.sets), Phase: \(timerModel.isCurrentIntensityLow ? "Low" : "High"), Low completed: \(timerModel.lowIntensityCompleted), High completed: \(timerModel.highIntensityCompleted)")
print("Remaining warnings: \(scheduledWarnings.count)")
```
These lines print debugging information about the current timer state and the number of remaining scheduled warnings. This helps with troubleshooting but doesn't affect functionality.

```swift
guard !scheduledWarnings.isEmpty else { return }
```
This line checks if there are any scheduled warnings. If the `scheduledWarnings` array is empty, the function returns immediately and does nothing.

```swift
if audioManager.isAnyAudioPlaying() {
    return
}
```
This line checks if any audio is currently playing (either a sound effect or speech). If audio is already playing, the function returns without playing any new warnings to prevent overlapping audio.

```swift
let now = Date()
var triggeredIndices: [Int] = []
```
These lines create a timestamp for the current time and initialize an empty array to track which warnings should be removed after processing.

```swift
for (index, warning) in scheduledWarnings.enumerated() {
```
This line starts a loop that iterates through each scheduled warning, keeping track of both the warning and its index in the array.

```swift
if now >= warning.time || now.timeIntervalSince(warning.time) > -0.5 {
```
This line checks if it's time to play the warning. It triggers if either:
1. The current time is equal to or later than the scheduled warning time, OR
2. The current time is within 0.5 seconds before the scheduled time (this provides a small buffer to ensure warnings aren't missed)

```swift
do {
    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
} catch {
    print("Failed to reactivate audio session: \(error)")
}
```
These lines ensure the audio session is active before playing any sounds. This is important for background audio playback.

```swift
switch warning.type {
```
This line starts a switch statement to handle different types of warnings.

```swift
case .phaseTransition:
    playWarningSound()
    print("Playing phase transition warning sound at \(now)")
```
These lines handle phase transition warnings by playing a warning sound and logging the action.

```swift
case .setCompletion(let setNumber):
```
This line handles set completion warnings and extracts the set number that was stored when the warning was scheduled.

```swift
let actualSetNumber = timerModel.currentSet
```
This line gets the current set number from the timer model. This is a critical line because it uses the current timer state rather than the stored set number.

```swift
if setNumber != actualSetNumber {
    print("Note: Set completion was scheduled for set \(setNumber) but playing for current set \(actualSetNumber)")
}
```
These lines log a message if there's a mismatch between the scheduled set number and the current set number, which helps with debugging.

```swift
if let lastPlayedTime = playedSetCompletionWarningsWithTime[actualSetNumber],
   now.timeIntervalSince(lastPlayedTime) < 10.0 {
    print("Skipping duplicate set completion announcement for set \(actualSetNumber) - played \(now.timeIntervalSince(lastPlayedTime)) seconds ago")
    break
}
```
These lines check if this set completion warning was already played recently (within the last 10 seconds). If so, it skips playing it again to prevent duplicates.

```swift
let isFinalSet = actualSetNumber == timerModel.sets
```
This line checks if this is the final set in the workout.

```swift
if isFinalSet || !playedSetCompletionWarnings.contains(actualSetNumber) {
```
This line determines if the warning should be played. It plays the warning if either:
1. This is the final set (always play final set warnings), OR
2. This set's completion warning hasn't been played before

```swift
playedSetCompletionWarnings.insert(actualSetNumber)
playedSetCompletionWarningsWithTime[actualSetNumber] = now
```
These lines record that this set's completion warning has been played by:
1. Adding the set number to the `playedSetCompletionWarnings` set
2. Recording the current time in the `playedSetCompletionWarningsWithTime` dictionary

```swift
let setCompletionText = "Set \(actualSetNumber) completing in 3, 2, 1, 0"
let _ = audioManager.speakText(setCompletionText, rate: 0.0)
print("Playing set completion announcement for set \(actualSetNumber) at \(now) (scheduled as set \(setNumber))")
```
These lines create the speech text using the current set number, speak the text, and log the action.

```swift
} else {
    print("Skipping duplicate set completion announcement for set \(actualSetNumber) at \(now)")
}
```
These lines log a message if the warning is skipped because it's a duplicate.

```swift
triggeredIndices.append(index)
break
```
These lines add the current warning's index to the list of triggered warnings and break out of the loop. The `break` ensures that only one warning is processed per function call, preventing multiple warnings from playing simultaneously.

```swift
}
}
```
These lines close the if statement and the for loop.

```swift
for index in triggeredIndices.sorted(by: >) {
    if index < scheduledWarnings.count {
        scheduledWarnings.remove(at: index)
        
        if index < backgroundWarningTimes.count {
            backgroundWarningTimes.remove(at: index)
        }
    }
}
```
These lines remove the triggered warnings from both the `scheduledWarnings` array and the `backgroundWarningTimes` array. The indices are sorted in descending order to ensure that removing items doesn't affect the indices of items that still need to be removed.

```swift
if scheduledWarnings.isEmpty {
    print("All warnings played, stopping background check timer")
    backgroundCheckTimer?.invalidate()
    backgroundCheckTimer = nil
}
```
These lines check if all warnings have been played. If so, they stop the background check timer to conserve resources.

```swift
}
```
This line closes the function.

## Key Insights:

1. **One Warning at a Time**: The function processes at most one warning per call, ensuring audio cues don't overlap.

2. **Current Set Number**: The function uses the current set number from the timer model, not the stored set number from when the warning was scheduled.

3. **Duplicate Prevention**: Multiple mechanisms prevent duplicate warnings:
   - Set-based tracking with `playedSetCompletionWarnings`
   - Timestamp-based tracking with `playedSetCompletionWarningsWithTime`
   - Special handling for the final set

4. **Resource Management**: The function cleans up resources by removing played warnings and stopping the timer when all warnings have been played.

5. **Error Handling**: The function includes error handling for audio session activation.

This function is designed to ensure that users receive accurate and timely audio cues even when the app is in the background for extended periods.
