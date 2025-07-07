# Line-by-Line Explanation of `scheduleBackgroundWarnings()` Function

The `scheduleBackgroundWarnings()` function is responsible for calculating and scheduling audio warnings that should be played while the app is in the background. Here's a detailed explanation of each line:

```swift
private func scheduleBackgroundWarnings() {
```
This line defines a private function named `scheduleBackgroundWarnings()` that can only be called from within the `TimerRunViewModel` class.

```swift
backgroundWarningTimes = []
scheduledWarnings = []
backgroundCheckTimer?.invalidate()
```
These lines reset the state by:
1. Clearing the array of warning times
2. Clearing the array of scheduled warnings
3. Invalidating any existing background check timer

```swift
let now = Date()
```
This line creates a timestamp for the current time, which will be used as the reference point for scheduling all warnings.

```swift
let currentRemainingSeconds = timerModel.currentMinutes * 60 + timerModel.currentSeconds
```
This line calculates the total number of seconds remaining in the current phase by converting minutes to seconds and adding the remaining seconds.

```swift
let isCurrentPhaseLastInSet = (timerModel.isCurrentIntensityLow && timerModel.highIntensityCompleted) ||
                             (!timerModel.isCurrentIntensityLow && timerModel.lowIntensityCompleted)
```
This line determines if the current phase is the last phase in the current set. This is true if either:
1. The current phase is low intensity and the high intensity phase is already completed, OR
2. The current phase is high intensity and the low intensity phase is already completed

```swift
if currentRemainingSeconds > warningSoundDuration {
    if !isCurrentPhaseLastInSet {
        let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
        scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
        print("Scheduled phase transition for current set-\(timerModel.currentSet), warning at \(warningTime)")
    }
}
```
These lines schedule a phase transition warning for the current phase if:
1. There's enough time left in the current phase to play a warning (more than the warning sound duration)
2. The current phase is not the last phase in the set (because for the last phase, we'll play a set completion warning instead)

The warning is scheduled to play `warningSoundDuration` seconds before the phase ends.

```swift
if isCurrentPhaseLastInSet && currentRemainingSeconds > setCompletionWarningSeconds {
    let setCompletionWarningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - setCompletionWarningSeconds))
    scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: timerModel.currentSet)))
    print("Scheduled set completion for current set-\(timerModel.currentSet), warning at \(setCompletionWarningTime)")
}
```
These lines schedule a set completion warning if:
1. The current phase is the last phase in the set
2. There's enough time left to play a warning (more than the set completion warning seconds)

The warning is scheduled to play `setCompletionWarningSeconds` seconds before the phase ends.

```swift
var timeOffset = TimeInterval(currentRemainingSeconds)
```
This line initializes a time offset variable with the remaining time in the current phase. This will be used to calculate when future phases will end.

```swift
var phaseSequence: [(isLow: Bool, isLastInSet: Bool, setNumber: Int)] = []
```
This line initializes an empty array to store information about future phases. Each element in the array will be a tuple containing:
1. Whether the phase is low intensity
2. Whether the phase is the last in its set
3. The set number

```swift
let currentPhaseIsLow = timerModel.isCurrentIntensityLow
let currentSetNumber = timerModel.currentSet
```
These lines store the current phase intensity and set number for easier reference.

```swift
if !isCurrentPhaseLastInSet {
    phaseSequence.append((isLow: !currentPhaseIsLow, isLastInSet: true, setNumber: currentSetNumber))
}
```
This line adds the next phase in the current set to the phase sequence if the current phase is not the last in the set. The next phase will:
1. Have the opposite intensity of the current phase
2. Be the last phase in the current set
3. Have the same set number as the current phase

```swift
for setIndex in currentSetNumber..<timerModel.sets {
    if setIndex > currentSetNumber || (setIndex == currentSetNumber && isCurrentPhaseLastInSet) {
        let nextSetNumber = setIndex + 1
        if nextSetNumber <= timerModel.sets {
            phaseSequence.append((isLow: timerModel.isLowIntensity, isLastInSet: false, setNumber: nextSetNumber))
            phaseSequence.append((isLow: !timerModel.isLowIntensity, isLastInSet: true, setNumber: nextSetNumber))
        }
    }
}
```
This loop adds phases for future sets to the phase sequence:
1. It iterates from the current set number up to (but not including) the total number of sets
2. For each iteration, it checks if:
   - The set index is greater than the current set number, OR
   - The set index equals the current set number AND the current phase is the last in the set
3. If the condition is met, it adds both phases (low and high intensity) for the next set number
4. The first phase is not the last in the set, and the second phase is the last in the set

```swift
for (_, phase) in phaseSequence.enumerated() {
```
This line starts a loop that iterates through each phase in the phase sequence.

```swift
timeOffset += TimeInterval(timerModel.totalSeconds)
```
This line updates the time offset by adding the duration of one phase. This represents the time at which the current phase in the iteration will end.

```swift
if !phase.isLastInSet && timeOffset > TimeInterval(warningSoundDuration) {
    let warningTime = now.addingTimeInterval(timeOffset - TimeInterval(warningSoundDuration))
    scheduledWarnings.append(ScheduledWarning(time: warningTime, type: .phaseTransition))
    print("Scheduled phase transition warning for set-\(phase.setNumber) at \(warningTime)")
}
```
These lines schedule a phase transition warning for the current phase in the iteration if:
1. The phase is not the last in its set
2. There's enough time to play a warning (more than the warning sound duration)

The warning is scheduled to play `warningSoundDuration` seconds before the phase ends.

```swift
if phase.isLastInSet && timeOffset > TimeInterval(setCompletionWarningSeconds) {
    let setCompletionWarningTime = now.addingTimeInterval(timeOffset - TimeInterval(setCompletionWarningSeconds))
    scheduledWarnings.append(ScheduledWarning(time: setCompletionWarningTime, type: .setCompletion(setNumber: phase.setNumber)))
    print("Scheduled set completion warning for set-\(phase.setNumber) at \(setCompletionWarningTime)")
}
```
These lines schedule a set completion warning for the current phase in the iteration if:
1. The phase is the last in its set
2. There's enough time to play a warning (more than the set completion warning seconds)

The warning is scheduled to play `setCompletionWarningSeconds` seconds before the phase ends.

```swift
}
```
This line closes the loop through the phase sequence.

```swift
backgroundWarningTimes = scheduledWarnings.map { $0.time }
```
This line extracts just the times from the scheduled warnings and stores them in the `backgroundWarningTimes` array for compatibility with older code.

```swift
print("Scheduled \(scheduledWarnings.count) warnings:")
for (index, warning) in scheduledWarnings.enumerated() {
    let timeInterval = warning.time.timeIntervalSince(now)
    let typeString: String
    switch warning.type {
    case .phaseTransition:
        typeString = "Phase Transition"
    case .setCompletion(let setNumber):
        typeString = "Set \(setNumber) Completion"
    }
    print("Warning \(index + 1): \(typeString) in \(timeInterval) seconds")
}
```
These lines print debugging information about all scheduled warnings, including their type and when they will play.

```swift
backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    self?.checkBackgroundWarnings()
}
```
This line creates a timer that fires every 0.5 seconds and calls the `checkBackgroundWarnings()` function. This timer is responsible for checking if any warnings should be played.

```swift
if let timer = backgroundCheckTimer {
    RunLoop.current.add(timer, forMode: .common)
}
```
These lines add the timer to the run loop with the `.common` mode, which ensures that the timer continues to fire even when the app is in the background.

```swift
}
```
This line closes the function.

## Key Insights:

1. **Comprehensive Warning Scheduling**: The function schedules warnings for both the current phase and all future phases, ensuring that warnings will be played at the appropriate times even if the app remains in the background for the entire workout.

2. **Two Types of Warnings**: The function schedules two types of warnings:
   - Phase transition warnings: Played before transitioning between low and high intensity
   - Set completion warnings: Played before completing a set

3. **Phase Sequence Calculation**: The function calculates a sequence of future phases based on the current timer state, taking into account:
   - The current phase intensity
   - Whether the current phase is the last in its set
   - The current set number
   - The total number of sets

4. **Time Offset Calculation**: The function uses a time offset to calculate when each future phase will end, which determines when warnings should be played.

5. **Background Timer Creation**: The function creates a timer that periodically checks if any warnings should be played, ensuring that warnings are played at the appropriate times even when the app is in the background.

This function is designed to ensure that all necessary warnings are scheduled when the app goes into the background, so that users receive accurate and timely audio cues throughout their workout.
