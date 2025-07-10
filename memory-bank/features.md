# PeakRush Timer - Key Features

## 🔄 Interval Training System

### Core Functionality

PeakRush Timer implements a comprehensive interval training system that alternates between low and high intensity phases across multiple sets, providing a structured workout experience.

### Implementation Details

- **Phase Alternation**: Automatically switches between low and high intensity phases
- **Set Management**: Tracks progress through configured number of sets
- **Completion Logic**: Detects when both phases of a set are completed
- **State Tracking**: Maintains flags for completed phases and sets

### User Experience

Users can configure their preferred starting intensity (low or high) and watch as the app automatically alternates between phases, with clear visual indicators of the current intensity level.

## ⏱️ Timer Configuration

### Core Functionality

The app provides a flexible configuration system that allows users to customize their workout parameters before starting.

### Implementation Details

- **Duration Selection**: Separate minute and second pickers (0-59)
- **Set Count**: Configurable number of workout sets (0-29)
- **Starting Intensity**: Toggle between starting with low or high intensity
- **Real-time Calculation**: Dynamic total workout duration updates

### User Experience

The configuration screen presents intuitive wheel pickers and toggles, with real-time feedback showing the total workout duration based on the current settings.

## 🔄 Visual Progress Tracking

### Core Functionality

During workout execution, the app provides clear visual feedback on progress through color-coded interface elements and dynamic time display.

### Implementation Details

- **State-Indicating Circle**: Color-coded circle that changes based on timer state (gray when not started, green for low intensity, red for high intensity, blue when completed)
- **Color Coding**: Green for low intensity, red for high intensity
- **Dynamic Icons**: Walking figure for low intensity, running figure for high intensity
- **Set Counter**: Clear display of current set and total sets

### User Experience

Users can quickly assess their current phase, remaining time, and overall progress through the workout with a glance at the visually distinct interface elements.

## 🔊 Enhanced Audio Feedback System

### Core Functionality

The app provides reliable audio cues to alert users of phase transitions and set completions, enabling eyes-free workout monitoring even during extended background operation.

### Implementation Details

- **Phase Transition Warnings**: Sound played N seconds before phase end
- **Set Completion Announcements**: Speech synthesis with countdown
- **Background Audio**: Continues playing even when app is backgrounded
- **Interruption Handling**: Manages audio session interruptions gracefully
- **Multi-Layer Duplicate Prevention**:
  - Set-based tracking of played warnings
  - Timestamp-based tracking with 10-second throttling
  - Special handling for final set warnings
  - Audio playback state checking
- **Current State Awareness**: Uses current timer state for announcements rather than scheduled state

### User Experience

Users receive timely and accurate audio alerts without duplicates, allowing them to focus on their workout while still staying informed of progress, even during extended background sessions or multiple app switches.

## 📱 Advanced Background Operation

### Core Functionality

PeakRush Timer continues functioning reliably even when the app is in the background or the device is locked, ensuring uninterrupted workout sessions with accurate timing.

### Implementation Details

- **Background Task Management**: Uses UIBackgroundTaskIdentifier for extended execution
- **Time Adjustment Algorithm**: Sophisticated algorithm to adjust timer for background time
- **Warning Scheduling System**: Pre-calculates and schedules all future warning times
- **Audio Session Configuration**: Optimized for background playback
- **Resource Management**: Proper cleanup of background resources
- **Comprehensive Documentation**: Detailed explanations of background processing logic

### User Experience

Users can switch to other apps, lock their device, or respond to notifications without disrupting their workout timing or missing audio cues, with the app intelligently adjusting to time spent in the background.

## 🔔 Enhanced Push Notifications

### Core Functionality

The app sends accurately timed push notifications for workout completion when in the background, ensuring users are informed at the right moment even when not actively watching the app.

### Implementation Details

- **Completion Notifications**: Alert when all sets are completed
- **Permission Management**: Graceful handling of notification authorization
- **Dynamic Buffer Calculation**:
  - Larger buffers for shorter intervals (8 seconds for ≤15 seconds)
  - Standard buffer for longer intervals (5 seconds)
  - Additional proportional buffer for very short intervals (≤10 seconds)
- **Duplicate Prevention**:
  - State tracking with `hasScheduledCompletionNotification`
  - Time-based throttling (10-second window)
  - Scheduled time comparison
  - Proper cleanup during background-foreground transitions

### User Experience

Users receive a congratulatory notification upon workout completion at the right time, without duplicates, even if their device is locked or they're using another app.

## ⚡ Seamless App Switching

### Core Functionality

The app handles brief app switches (like checking messages or responding to notifications) without disrupting the timer or causing jumps in the countdown.

### Implementation Details

- **Smart Timer Preservation**: Never invalidates timer for brief app switches (<3 seconds)
- **Timer Firing Compensation**: Detects irregular timer firing and updates multiple times to catch up
- **State Preservation**: Maintains timer state during brief background periods
- **Inactive State Handling**: Properly handles `.inactive` state during app switches
- **Timestamp Tracking**: Records precise state change times for accurate adjustments

### User Experience

Users can quickly check other apps or respond to notifications without experiencing timer jumps or disruptions when returning to the workout, providing a seamless experience across app switches.

## ⏯️ Comprehensive Timer Controls

### Core Functionality

The app provides a full set of controls for managing the timer during workout execution.

### Implementation Details

- **Start/Pause**: Toggle between running and paused states
- **Reset**: Return to initial configuration state
- **Back Navigation**: Return to configuration screen
- **Start Again**: Quick restart after completion

### User Experience

Users have complete control over their workout session with intuitive buttons that adapt based on the current timer state.

## 🔄 Robust State Preservation

### Core Functionality

The app maintains workout state across app lifecycle events, including background/foreground transitions and interruptions.

### Implementation Details

- **Scene Phase Monitoring**: Tracks app state changes via ScenePhase
- **Timestamp Tracking**: Records state change times
- **State Reconstruction**: Rebuilds timer state from elapsed time
- **Warning State Management**: Tracks which warnings have been played
- **Background Duration Detection**: Different handling for brief vs. longer background periods

### User Experience

Users experience a seamless workout session even when interrupted by calls, notifications, or briefly switching to other apps, with the app intelligently adapting to different interruption scenarios.

## 📊 Workout Statistics

### Core Functionality

The app displays key statistics about the current workout configuration and progress.

### Implementation Details

- **Total Duration**: Calculated workout length (minutes:seconds)
- **Current Progress**: Time remaining in current phase
- **Set Progress**: Current set number out of total sets
- **Phase Indication**: Clear labeling of current intensity phase

### User Experience

Users can easily track their overall workout progress and see exactly how much time remains in the current phase and overall session.

## 🎨 Adaptive Visual Design

### Core Functionality

The interface adapts to the current workout state with color changes, icon updates, and dynamic text.

### Implementation Details

- **Dynamic Colors**: Interface elements change color based on intensity
- **Conditional Styling**: Button appearance changes based on timer state
- **State Visualization**: Circular indicator changes color based on timer state
- **State-Based Text**: Labels update to reflect current state

### User Experience

The visual design provides immediate feedback about the current workout state, with intuitive color coding and clear visual hierarchy.

## 🔄 Seamless Phase Transitions

### Core Functionality

The app handles transitions between phases and sets smoothly, with appropriate feedback and state updates.

### Implementation Details

- **Automatic Progression**: Moves to next phase when current one completes
- **Set Increment**: Advances set counter when both phases complete
- **State Reset**: Resets phase completion flags for new sets
- **Completion Detection**: Identifies when all sets are finished

### User Experience

Users experience fluid transitions between workout phases with clear audio and visual cues indicating the change in intensity.

## 🔒 Validation Logic

### Core Functionality

The app ensures that users can only start a workout with valid configuration parameters.

### Implementation Details

- **Parameter Checking**: Verifies non-zero duration and set count
- **Button Disabling**: Prevents starting with invalid configuration
- **Visual Feedback**: Changes button appearance for invalid states
- **Real-time Validation**: Updates validity as user changes parameters

### User Experience

The start button is disabled and visually distinct when the configuration is invalid, preventing user frustration from attempting to start an improperly configured workout.

## 📝 Comprehensive Documentation

### Core Functionality

The app includes detailed documentation for complex background processing logic, ensuring maintainability and facilitating future development.

### Implementation Details

- **Class-Level Documentation**: Overview of key classes and their responsibilities
- **Method Documentation**: Detailed explanations of critical methods
- **Inline Comments**: Explanations of complex code sections
- **Line-by-Line Explanations**: Comprehensive documentation of critical functions
- **Bug Analysis**: Detailed analysis of bugs and their fixes

### Developer Experience

Developers can easily understand the complex background processing logic, audio system, and notification system, facilitating future maintenance and enhancements.
