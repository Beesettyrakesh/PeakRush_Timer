# PeakRush Timer - Active Context

## 🔍 Current Focus

The current development focus is on stabilizing and documenting the background audio system and timer functionality, with particular emphasis on:

1. **Background Audio System Documentation**: Creating comprehensive documentation for the complex background audio system to ensure maintainability
2. **Timer Jumping Bug Fix**: Finalizing and testing the enhanced fix for timer jumping during brief app switches
3. **Memory Bank Updates**: Keeping the Memory Bank up-to-date with recent changes and improvements

## 🔄 Recent Changes

### Background Processing Improvements

- **Enhanced Timer Jumping Fix**: Implemented a sophisticated solution to prevent timer jumps during brief app switches
  - Never invalidate timer for brief app switches (<3 seconds)
  - Smart timer firing compensation for irregular timer firing
  - Proper handling of inactive state during app switches
  - Improved resource cleanup when returning from background

- **Background Warning System Enhancements**:
  - Added multi-layer duplicate prevention for audio cues
  - Implemented timestamp-based tracking of played warnings
  - Added special handling for final set warnings
  - Improved current state awareness for accurate announcements

- **Notification System Improvements**:
  - Implemented dynamic buffer calculation based on interval duration
  - Added multiple layers of duplicate prevention
  - Improved total remaining time calculation
  - Enhanced notification cancellation logic

### Documentation Improvements

- **Line-by-Line Explanations**:
  - Created detailed explanation of `checkBackgroundWarnings()` function
  - Created detailed explanation of `scheduleBackgroundWarnings()` function
  - Documented the set-2 warnings issue and its solution

- **Bug Analysis and Fixes**:
  - Documented the timer jumping bug and its enhanced fix
  - Analyzed the duplicate speech warnings issue
  - Documented the premature notification issue and its solution

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
4. **Time-based throttling**: Using time windows (10 seconds) to prevent duplicates
5. **Scheduled time tracking**: Tracking when notifications are scheduled to fire

This comprehensive approach ensures that users don't hear duplicate audio cues or receive duplicate notifications, even with multiple background-foreground transitions.

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

1. **Timer Behavior**: We discovered that invalidating and recreating the timer when returning from brief background periods causes noticeable jumps in the countdown. Preserving the timer state completely for brief app switches provides a much smoother experience.

2. **Background Audio Scheduling**: We learned that scheduling audio warnings with specific set numbers at scheduling time can lead to incorrect announcements if the timer advances while in the background. Using the current timer state when playing warnings ensures accurate announcements.

3. **Notification Timing**: We found that short intervals require larger buffers to prevent premature notifications, due to their sensitivity to timing variations. Dynamic buffer calculation based on interval duration provides more accurate notification timing.

4. **Documentation Importance**: We realized that complex background processing logic requires comprehensive documentation for future maintenance. Line-by-line explanations of critical functions have proven invaluable for understanding and debugging.

5. **Multi-Layer Protection**: We learned that a single mechanism for preventing duplicates is not sufficient. Multiple layers of protection (set-based, timestamp-based, state flags, time-based throttling) provide more robust duplicate prevention.

## 🔄 Current Challenges

1. **Extended Background Operation**: Ensuring reliable audio cues when the app has been in the background for extended periods (>30 minutes) remains challenging due to iOS background execution limits.

2. **Battery Usage**: Background operation with continuous audio session activation consumes significant battery power. We need to explore more efficient approaches.

3. **Testing Edge Cases**: Testing all possible combinations of background-foreground transitions, interruptions, and timer states is challenging. We need a more systematic approach to testing.

4. **Documentation Maintenance**: Keeping comprehensive documentation up-to-date with code changes requires discipline. We need to establish better processes for documentation updates.

5. **Cross-Device Consistency**: Ensuring consistent behavior across different iOS devices and versions remains challenging. We need more extensive device testing.
