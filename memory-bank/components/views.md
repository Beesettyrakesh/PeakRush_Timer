# PeakRush Timer - Views

The PeakRush Timer app uses SwiftUI for its user interface, with three main view components organized in a navigation hierarchy.

## ContentView

`ContentView` serves as the root container for the application, providing the navigation infrastructure.

```swift
struct ContentView: View {
    var body: some View {
        NavigationStack {
            TimerConfigView()
        }
    }
}
```

### Key Features:

- Uses `NavigationStack` to enable navigation between views
- Sets `TimerConfigView` as the root view of the application
- Minimal implementation as it primarily serves as a container

## TimerConfigView

`TimerConfigView` is the initial screen users interact with, allowing them to configure their interval workout parameters.

```swift
struct TimerConfigView: View {
    @StateObject private var viewModel = TimerConfigViewModel()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(...)

            VStack(spacing: 20) {
                // App title
                VStack(spacing: 4) { ... }

                // Interval and sets configuration
                VStack(spacing: 16) { ... }

                // Intensity toggle
                HStack { ... }

                Spacer()

                // Total workout duration display
                HStack { ... }

                // Start button (NavigationLink)
                NavigationLink(destination: TimerRunView(viewModel: viewModel.createTimerRunViewModel())) { ... }
            }
        }
        .navigationBarHidden(true)
    }
}
```

### Key UI Components:

1. **Header Section**

   - App title "PeakRush" with subtitle "Interval Timer"
   - Custom font styling and color treatment

2. **Configuration Controls**

   - Interval Duration: Two wheel pickers for minutes and seconds
   - Sets: Wheel picker for number of sets
   - Visual grouping with icons and labels

3. **Intensity Toggle**

   - Switch control to select starting intensity (low/high)
   - Text label explaining the option

4. **Workout Summary**

   - Total workout duration calculation
   - Explanatory text about set structure
   - Formatted time display (MM:SS)

5. **Action Button**
   - "Let's Go" button to start the workout
   - Gradient background with conditional styling
   - Disabled state when configuration is invalid
   - NavigationLink to TimerRunView

### Visual Design Elements:

- **Background**: Linear gradient from system background to system gray
- **Cards**: White background with rounded corners and subtle shadows
- **Typography**: Hierarchical text sizes with primary/secondary color treatment
- **Iconography**: SF Symbols for visual indicators (timer, repeat)
- **Color Coding**: Blue for interval, green for sets, orange for intensity

### Data Binding:

The view uses `@StateObject` to create and maintain a `TimerConfigViewModel` instance, with bindings to:

- Minutes picker
- Seconds picker
- Sets picker
- Intensity toggle

### Navigation:

When the user taps "Let's Go", the view creates a `TimerRunViewModel` using the factory method on the configuration view model and navigates to `TimerRunView`.

## TimerRunView

`TimerRunView` is the active workout screen where users monitor and control their interval training session.

```swift
struct TimerRunView: View {
    @ObservedObject var viewModel: TimerRunViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(...)

            VStack(spacing: 30) {
                // Navigation header with back button
                HStack { ... }

                // Workout stats (sets, interval, total time)
                HStack(spacing: 12) { ... }

                // Timer display with circular progress
                VStack(spacing: 16) {
                    // Intensity label
                    Text(viewModel.intensityText)

                    // Circular progress with timer
                    ZStack {
                        // Background circle
                        Circle().stroke(...)

                        // Progress circle
                        Circle().stroke(...)

                        // Timer display and set counter
                        VStack(spacing: 8) { ... }
                    }
                }

                Spacer()

                // Control buttons
                VStack(spacing: 12) {
                    // Start/Pause or Start Again button
                    Button { ... } label: { ... }

                    // Reset or Modify Settings button
                    Button { ... } label: { ... }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear { viewModel.initializeTimer() }
        .onDisappear { viewModel.stopTimer() }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
    }
}
```

### Key UI Components:

1. **Navigation Header**

   - Back button to return to configuration
   - App title centered in the header

2. **Workout Statistics**

   - Sets: Current set count and total sets
   - Interval: Configured interval duration
   - Total: Total workout duration

3. **Timer Display**

   - Intensity label (Low/High Intensity)
   - Circular progress indicator
   - Current time remaining (MM:SS)
   - Set counter (current/total)
   - Intensity icon (walking/running figure)

4. **Control Buttons**
   - Primary action: Start/Pause or Start Again (when completed)
   - Secondary action: Reset or Modify Settings

### Visual Design Elements:

- **Background**: Matching gradient from configuration view
- **Progress Circle**: Color-coded based on intensity (green for low, red for high)
- **Cards**: White background with rounded corners for statistics
- **Typography**: Monospaced font for timer display
- **Iconography**: Dynamic icons based on intensity state
- **Color Coding**: Green/red for intensity states, blue for completion

### State Management:

The view observes a `TimerRunViewModel` instance passed from the configuration view, with reactive updates to:

- Timer display
- Progress circle
- Intensity indicators
- Control button states

### Lifecycle Management:

- **onAppear**: Initializes the timer
- **onDisappear**: Stops the timer
- **onChange(scenePhase)**: Handles app state transitions (foreground/background)

### User Interactions:

1. **Start/Pause**: Toggles the timer running state
2. **Reset**: Resets the timer to initial configuration
3. **Back/Modify Settings**: Returns to configuration view
4. **Start Again**: Appears after workout completion to restart

## View Hierarchy and Navigation Flow

```
ContentView (NavigationStack)
    │
    └── TimerConfigView (@StateObject viewModel: TimerConfigViewModel)
            │
            └── TimerRunView (@ObservedObject viewModel: TimerRunViewModel)
```

The navigation flow is unidirectional, with the configuration view creating and passing a view model to the run view. The run view can dismiss itself to return to the configuration view.

## Responsive Design Considerations

- **Layout Adaptability**: VStack and HStack combinations with Spacer elements
- **Dynamic Type**: Font sizes using system sizes (title, headline, etc.)
- **Safe Area**: Content respects safe areas with padding
- **Accessibility**: SF Symbols for icons, clear text labels

## SwiftUI Features Utilized

- **Environment Values**: `.dismiss` for navigation, `.scenePhase` for lifecycle
- **State Management**: `@StateObject`, `@ObservedObject`
- **Navigation**: NavigationStack, NavigationLink
- **Layout**: ZStack, VStack, HStack with spacing
- **Controls**: Buttons, Pickers, Toggle
- **Graphics**: LinearGradient, Circle with stroke styles
- **Lifecycle**: onAppear, onDisappear, onChange
