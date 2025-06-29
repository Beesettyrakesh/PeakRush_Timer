# PeakRush Timer

PeakRush Timer is a sophisticated interval training application for iOS that enables users to create and execute high/low intensity workout cycles with advanced background processing capabilities.

![PeakRush Timer App](https://via.placeholder.com/800x400?text=PeakRush+Timer+App)

## Features

- **Customizable Interval Training**: Configure workout duration, sets, and intensity
- **Visual Progress Tracking**: Circular progress indicator with color-coded phases
- **Audio Feedback**: Sound cues and speech synthesis for phase transitions
- **Background Operation**: Continues functioning when app is backgrounded
- **Push Notifications**: Alerts for workout completion
- **State Preservation**: Maintains workout state across app lifecycle events

## Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## Installation

1. Clone the repository:

```bash
git clone https://github.com/yourusername/PeakRush_Timer.git
cd PeakRush_Timer
```

2. Open the project in Xcode:

```bash
open PeakRush_Timer.xcodeproj
```

## Testing with iOS Simulator

### Setting Up the Simulator

1. Open the project in Xcode
2. At the top of the Xcode window, select a simulator device from the scheme dropdown menu (e.g., "iPhone 14 Pro")
3. Click the "Run" button (▶️) or press `Cmd + R` to build and run the app on the selected simulator

### Testing Background Mode in Simulator

1. Launch the app in the simulator and start a timer
2. To simulate the app going into the background:
   - Press `Cmd + H` to go to the home screen
   - Or click "Device" in the simulator menu, then "Home"
3. To test background audio:
   - Ensure your Mac's volume is turned up
   - Background audio warnings should play at the scheduled times
4. To bring the app back to the foreground:
   - Click on the app icon in the simulator's home screen
   - Or use the App Switcher by pressing `Cmd + Tab` in the simulator

### Testing Notifications in Simulator

1. Start a timer and send the app to the background
2. When the timer completes, a notification should appear
3. To view all notifications:
   - Swipe down from the top of the simulator screen
   - Or click "Device" in the simulator menu, then "Notification Center"

### Simulating Interruptions

1. To simulate a phone call interruption:
   - Start a timer
   - Click "Device" in the simulator menu
   - Select "Toggle In-Call Status Bar"
2. To simulate audio session interruptions:
   - Play audio in another app on your Mac while the timer is running

## Testing on Physical iPhone Devices

### Setting Up Your Device for Development

1. Connect your iPhone to your Mac using a USB cable
2. In Xcode, go to "Window" > "Devices and Simulators"
3. Select your device and ensure it's recognized by Xcode
4. If this is your first time using the device for development:
   - Go to Settings > Privacy & Security > Developer Mode on your iPhone
   - Enable Developer Mode and restart your device
   - Trust your Mac when prompted on your iPhone

### Building to Your Device

1. In Xcode, select your iPhone from the scheme dropdown menu at the top
2. If you haven't set up a development team:
   - Click on the project file in the Project Navigator
   - Select the "PeakRush_Timer" target
   - Go to the "Signing & Capabilities" tab
   - Select your Apple ID in the "Team" dropdown
   - Xcode will automatically manage the provisioning profile
3. Click the "Run" button (▶️) or press `Cmd + R` to build and run the app on your device

### Testing Background Mode on Device

1. Launch the app and start a timer
2. Press the home button or swipe up (depending on your iPhone model) to send the app to the background
3. Lock your device to test background execution during device sleep
4. The app should continue to function, playing audio cues at the appropriate times
5. When the timer completes, you should receive a notification

### Testing Audio Features

1. Start a timer and test the following scenarios:
   - Play music from another app to verify audio mixing
   - Receive a phone call to test interruption handling
   - Use Siri to test speech synthesis interruptions
2. The app should properly pause and resume audio when interrupted

### Debugging Background Execution Issues

1. If background audio is not working:
   - Check that your device is not in silent mode
   - Verify that notifications are enabled for the app in Settings
   - Ensure Background Modes are properly configured in the app's capabilities
2. For background execution issues:
   - Connect your device to Xcode
   - Start a debugging session
   - Check the console logs for any error messages
   - Use the Debug Navigator to monitor memory and CPU usage

## Advanced Debugging Techniques

### Console Logging

The app includes extensive logging for background operations, audio sessions, and timer state changes. To view these logs:

1. In Xcode, show the Debug area by clicking the button in the bottom right or pressing `Cmd + Shift + Y`
2. Filter the console output by typing "PeakRush" in the search field

### Debugging Background Tasks

1. To monitor background task execution:
   - Add breakpoints in the `beginBackgroundTask()` and `endBackgroundTask()` methods
   - Enable "Automatically continue after evaluating" in the breakpoint settings
   - Add log messages to track task IDs and execution time

### Testing Edge Cases

1. **Long Background Duration**:

   - Start a timer
   - Send the app to the background
   - Wait for an extended period (10+ minutes)
   - Return to the app and verify the timer state is correctly adjusted

2. **Low Memory Conditions**:

   - In Xcode, select "Debug" > "Simulate Memory Warning" while the app is running
   - Verify the app continues to function correctly

3. **Audio Session Conflicts**:
   - Play audio in multiple apps simultaneously
   - Verify the app's audio behavior when competing for audio resources

## Troubleshooting

### Common Issues and Solutions

1. **App crashes when going to background**:

   - Check that background modes are properly configured in the app's capabilities
   - Verify that audio session configuration is correct
   - Ensure background tasks are properly started and ended

2. **Audio not playing in background**:

   - Verify that the audio session category is set to `.playback`
   - Check that the audio session is active
   - Ensure the device is not in silent mode

3. **Notifications not appearing**:

   - Check that notification permissions have been granted
   - Verify that notifications are scheduled correctly
   - Ensure the app is properly registered for notifications

4. **Timer state incorrect after background**:
   - Check the implementation of `adjustTimerForBackgroundTime()`
   - Verify that timestamps are being recorded correctly
   - Ensure the state reconstruction logic is working as expected

### Getting Help

If you encounter issues not covered in this guide, please:

1. Check the console logs for error messages
2. Review the relevant code in the project
3. File an issue on the GitHub repository with detailed reproduction steps

## Project Structure

For a detailed understanding of the project architecture and components, refer to the documentation in the `memory-bank` directory:

- `project-overview.md` - High-level summary of the application
- `architecture.md` - Technical architecture details
- `components/` - Documentation of individual components
- `features.md` - Key functionality documentation
- `technical-notes.md` - Implementation highlights

## License

[Include license information here]

## Acknowledgements

[Include acknowledgements here]
