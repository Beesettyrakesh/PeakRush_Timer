# PeakRush Timer - Active Context

## 🔍 Current Focus

The current development focus is on implementing comprehensive unit testing and further stabilizing the app, with particular emphasis on:

1. **Extended Background Operation Reliability**: Addressing issues that occur during longer workouts (12+ sets)
2. **Unit Testing Implementation**: Developing and refining a comprehensive testing suite for core functionality
3. **Testing Best Practices**: Establishing patterns for testing system framework interactions
4. **Background Audio System Documentation**: Maintaining comprehensive documentation for the complex background audio system
5. **Memory Bank Updates**: Keeping the Memory Bank up-to-date with recent changes and improvements

## 🔄 Recent Changes

### Newly Identified Issues in Extended Background Operation

Recent testing with longer workouts (12 sets) has revealed several issues that occur during extended background operation:

1. **Audio Playback Failure in Long Workouts**: The app fails to play warning sounds for later sets, likely due to iOS reclaiming audio resources after prolonged background execution.

2. **Background Task Expiration**: Background tasks expire despite the renewal system, affecting audio playback and notifications.

3. **Speech Interruption**: Speech synthesis is interrupted during longer workouts, resulting in incomplete audio cues.

4. **Missing Phase Transition Warning for Set 2**: The phase sequence generation logic is skipping set 2 in the warning schedule.

5. **Inconsistent Warning Playback Timing**: Warnings are played at unexpected times due to system throttling during extended background operation.

6. **Notification Timing Issue**: Notifications may still be sent before speech warnings complete, particularly for longer workouts.

7. **Minor Log Issues**: Several minor issues including typos in log messages, inconsistent formatting, and redundancy.

A detailed analysis and implementation plan has been documented in [extended-background-operation-issues.md](extended-background-operation-issues.md).

### Background Processing Improvements

- **Enhanced Timer Jumping Fix**: Implemented a sophisticated solution to prevent timer jumps during brief app switches
  - Never invalidate timer for brief app switches (<3 seconds)
  - Smart timer firing compensation for irregular timer firing
  - Proper handling of inactive state during app switches
  - Improved resource cleanup when returning from background

- **Audio Session Management Enhancements**:
  - Implemented audio session keep-alive mechanism with periodic refreshes
  - Added audio session health checks to detect when sessions become invalid
  - Created background task renewal system to extend background execution time
  - Enhanced error recovery with multiple retry attempts for audio session activation
  - Added adaptive refresh intervals based on workout duration and warning proximity

- **Background Warning System Enhancements**:
  - Added multi-layer duplicate prevention for audio cues
  - Implemented timestamp-based tracking of played warnings
  - Added special handling for final set warnings
  - Improved current state awareness for accurate announcements
  - Enhanced warning playback with robust retry mechanisms

- **Notification System Improvements**:
  - Implemented dynamic buffer calculation based on interval duration
  - Added content-based notification deduplication with 30-second window
  - Improved coordination between speech warnings and notifications
  - Enhanced notification metadata for better tracking
  - Fixed race conditions between speech completion and notification sending

### Documentation Improvements

- **Line-by-Line Explanations**:
  - Created detailed explanation of `checkBackgroundWarnings()` function
  - Created detailed explanation of `scheduleBackgroundWarnings()` function
  - Documented the set-2 warnings issue and its solution

- **Bug Analysis and Fixes**:
  - Documented the timer jumping bug and its enhanced fix
  - Analyzed the duplicate speech warnings issue
  - Documented the premature notification issue and its solution
  - Documented the set intensity bug where new sets were not starting with the configured intensity
  - Documented the completion notification timing issue where notifications were sent before final speech warning
  - Analyzed the delayed log printing issue and implemented predictive logging solution

- **Implementation Guides**:
  - Created step-by-step guide for implementing the timer jumping fix
  - Documented the background audio system architecture

### Code Improvements

- **Resource Management**:
  - Added `cleanupBackgroundResources()` method for proper resource cleanup
  - Improved background task management
  - Enhanced audio session handling

- **State Tracking**:
  - Added `isInBackgroundMode` flag for better state tracking
  - Added `hasScheduledCompletionNotification` flag to prevent duplicate notifications
  - Added `scheduledNotificationCompletionTime` for better notification timing
  - Added `playedSetCompletionWarningsWithTime` for timestamp-based duplicate prevention

## 🔧 Active Decisions and Considerations

### Timer Preservation Strategy

We've decided to never invalidate the timer for brief app switches (<3 seconds) to prevent timer jumps. This is a change from our previous approach of invalidating and recreating the timer when returning from background. The new approach preserves the timer state completely for brief app switches, which provides a more seamless experience.

### Duplicate Prevention Strategy

We've implemented multiple layers of duplicate prevention for audio cues and notifications:

1. **Set-based tracking**: Using `Set<Int>` to track which warnings have been played
2. **Timestamp-based tracking**: Using `[Int: Date]` to track when warnings were last played
3. **State flags**: Using boolean flags to track warning states
4. **Time-based throttling**: Using time windows (10-30 seconds) to prevent duplicates
5. **Scheduled time tracking**: Tracking when notifications are scheduled to fire
6. **Content-based deduplication**: Using notification content to identify similar notifications
7. **Notification history**: Maintaining a history of recent notifications with timestamps

This comprehensive approach ensures that users don't hear duplicate audio cues or receive duplicate notifications, even with multiple background-foreground transitions or during extended background operation.

### Buffer Calculation Strategy

We've implemented a dynamic buffer calculation strategy for notifications based on interval duration:

1. **Short intervals** (≤15 seconds): 8-second buffer
2. **Longer intervals**: 5-second buffer
3. **Very short intervals** (≤10 seconds): Additional proportional buffer

This approach ensures that notifications appear at the correct time, with larger buffers for shorter intervals which are more sensitive to timing variations.

## 📋 Next Steps

1. **Testing**: Conduct comprehensive testing of the background audio system and timer functionality
   - Test with various interval durations (very short, short, medium, long)
   - Test with multiple background-foreground transitions
   - Test with interruptions (phone calls, other apps playing audio)
   - Test with different device states (locked, screen off)

2. **User Authentication System**: Begin planning and implementation of user authentication system
   - Research authentication options (Firebase, Auth0, custom)
   - Design user registration and login flows
   - Plan secure storage of user credentials

3. **Database Integration**: Plan for saving workout configurations
   - Research database options (Core Data, Realm, Firebase)
   - Design data model for workout configurations
   - Plan sync capabilities for future cross-platform support

4. **Settings Screen**: Design and implement settings screen
   - Audio preferences (volume, speech on/off)
   - Notification preferences
   - UI preferences (dark mode, color themes)
   - User profile management

## 💡 Recent Insights and Learnings

1. **Audio Session Management**: We discovered that iOS may reclaim audio resources after extended background operation, requiring periodic refreshes and health checks to maintain audio capabilities.

2. **Background Task Renewal**: We learned that background tasks can be renewed before expiration to extend background execution time, significantly improving reliability during long workouts.

3. **Speech-Notification Coordination**: We found that race conditions between speech warnings and notifications can cause user confusion. Ensuring speech completes before sending notifications provides a better user experience.

4. **Content-Based Deduplication**: We discovered that tracking notification content (not just identifiers) is more effective for preventing duplicates, especially when notifications are generated from different code paths.

5. **Timer Behavior**: We confirmed that invalidating and recreating the timer when returning from brief background periods causes noticeable jumps in the countdown. Preserving the timer state completely for brief app switches provides a much smoother experience.

6. **Background Audio Scheduling**: We reinforced our understanding that scheduling audio warnings with specific set numbers at scheduling time can lead to incorrect announcements if the timer advances while in the background. Using the current timer state when playing warnings ensures accurate announcements.

7. **Notification Timing**: We confirmed that short intervals require larger buffers to prevent premature notifications, due to their sensitivity to timing variations. Dynamic buffer calculation based on interval duration provides more accurate notification timing.

8. **Multi-Layer Protection**: We validated that multiple layers of protection (set-based, timestamp-based, state flags, time-based throttling, content-based deduplication) provide more robust duplicate prevention than any single mechanism.

9. **System Framework Testing**: We discovered that attempting to directly mock system classes like AVAudioPlayer and AVAudioSession can lead to memory access issues (EXC_BAD_ACCESS errors). Creating standalone mock classes that implement the same interface is more reliable.

10. **TestableAudioManager Pattern**: We developed a pattern using inheritance to create testable versions of classes that interact with system frameworks. By overriding methods that would normally interact with system frameworks, we can test the logic without making actual system calls.

11. **UI Component Testability**: We found that simplifying UI components (e.g., changing from LinearGradient to Color) can significantly improve testability while maintaining the same visual appearance.

12. **Protocol-Based Testing**: We implemented a protocol-based approach for testing code that interacts with system singletons like UNUserNotificationCenter, which proved more effective than method swizzling or other techniques.

13. **Set Intensity Preservation**: We discovered that when transitioning between sets, we need to explicitly reset to the user's configured intensity preference rather than just toggling from the previous phase. This ensures consistent behavior across all sets in the workout.

14. **Swift API Understanding**: We learned the importance of understanding Swift API return types, particularly with system frameworks. For example, AVAudioSession's `setActive()` method returns Void, not Bool, and properties like `isOtherAudioPlaying` don't throw errors. Proper handling of these API characteristics is essential for code correctness.

15. **Return Type Consistency**: We discovered the importance of ensuring method return types match their usage. When a method is used in a conditional statement, it must return a Boolean value. This consistency improves code readability and prevents compiler errors.

## 🔄 Current Challenges

1. **Extended Background Operation**: While significantly improved, ensuring reliable audio cues when the app has been in the background for very long periods (>45 minutes) remains challenging due to iOS background execution limits.

2. **Battery Usage**: Background operation with periodic audio session refreshes still consumes significant battery power. We need to explore more efficient approaches, possibly with adaptive refresh intervals based on battery level.

3. **Testing System Framework Interactions**: Testing code that interacts with system frameworks like AVFoundation and UserNotifications remains challenging. We've developed patterns like TestableAudioManager, but need to apply these consistently across the codebase.

4. **Documentation Maintenance**: Keeping comprehensive documentation up-to-date with code changes requires discipline. We need to establish better processes for documentation updates.

5. **Cross-Device Consistency**: Ensuring consistent behavior across different iOS devices and versions remains challenging. We need more extensive device testing, particularly on older devices which may have more limited background execution capabilities.

6. **System Termination**: While we've improved notification reliability, the app may still be terminated by the system after extended background operation. We need to explore additional strategies for handling system termination gracefully.

7. **Test Coverage**: While we've implemented unit tests for key components, we need to improve overall test coverage, particularly for edge cases and error conditions.

8. **UI Testing**: We've focused on unit testing core functionality, but still need to implement UI tests to verify the user interface behaves correctly.
