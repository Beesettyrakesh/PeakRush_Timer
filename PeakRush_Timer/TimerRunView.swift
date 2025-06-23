import SwiftUI
import UserNotifications
import AVFoundation

struct TimerRunView: View {
    let minutes: Int
    let seconds: Int
    let sets: Int
    let isLowIntensity: Bool
    let totalWorkoutMinutes: Int
    let totalWorkoutSeconds: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var currentMinutes: Int = 0
    @State private var currentSeconds: Int = 0
    @State private var currentSet: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var timer: Timer?
    @State private var isTimerCompleted: Bool = false
    @State private var isCurrentIntensityLow: Bool = true
    @State private var lowIntensityCompleted: Bool = false
    @State private var highIntensityCompleted: Bool = false
    
    @State private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @State private var lastActiveTimestamp: Date = Date()
    
    // Audio player for warning sound
    @State private var audioPlayer: AVAudioPlayer?
    @State private var warningTriggered: Bool = false
    
    // Background audio scheduling
    @State private var backgroundWarningTimes: [Date] = []
    @State private var backgroundCheckTimer: Timer?
    
    // Warning sound duration - will be calculated dynamically
    @State private var warningSoundDuration: Int = 0
    
    var totalSeconds: Int {
        minutes * 60 + seconds
    }
    
    var currentTotalSeconds: Int {
        currentMinutes * 60 + currentSeconds
    }
    
    var circleColor: LinearGradient {
        if !isTimerRunning && !isTimerCompleted {
            return LinearGradient(
                colors: [.gray, .gray],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isTimerCompleted {
            return LinearGradient(
                colors: [.blue, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            if isCurrentIntensityLow {
                return LinearGradient(
                    colors: [.green, .green],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [.red, .red],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }
    
    var intensityText: String {
        if !isTimerRunning && !isTimerCompleted {
            return "Ready"
        } else if isTimerCompleted {
            return "Completed!"
        } else {
            return isCurrentIntensityLow ? "Low Intensity" : "High Intensity"
        }
    }
    
    var checkSetCompleted: Bool {
        return lowIntensityCompleted && highIntensityCompleted
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
                
            VStack(spacing: 30) {
                HStack {
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                            Text("Back")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.blue)
                    }
                        
                    Spacer()
                }
                .overlay(
                    Text("PeakRush")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                )
                .padding(.horizontal, 20)
                .padding(.top, 10)
                    
                HStack(spacing: 12) {
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat")
                                .font(.title3)
                                .foregroundStyle(.green)
                                .frame(width: 20, height: 20)
                            
                            Text("SETS")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(sets)")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 80)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 20)
                                
                            Text("INTERVAL")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 80)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "hourglass")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 20, height: 20)
                                
                            Text("Total")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(height: 25)
                            
                        Text("\(String(format: "%02d", totalWorkoutMinutes)):\(String(format: "%02d", totalWorkoutSeconds))")
                            .font(.system(size: 20, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(height: 24)
                    }
                    .frame(width: 120, height: 80)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                }
                .padding(.horizontal, 20)
                
                VStack(spacing: 16) {
                    Text(intensityText)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle({
                            if isTimerCompleted {
                                Color.blue
                            } else if !isTimerRunning {
                                Color.black
                            } else {
                                isCurrentIntensityLow ? Color.green : Color.red
                            }
                        }())
                        .multilineTextAlignment(.center)
                    
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray), lineWidth: 8)
                            .frame(width: 250, height: 250)
                        
                        Circle()
                            .stroke(circleColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 250, height: 250)
                        
                        VStack(spacing: 8) {
                            Image(systemName: isCurrentIntensityLow ? "figure.walk" : "figure.run")
                                .font(.largeTitle)
                                .foregroundStyle({
                                    if isTimerCompleted {
                                        Color.blue
                                    } else if !isTimerRunning {
                                        Color.gray
                                    } else {
                                        isCurrentIntensityLow ? Color.green : Color.red
                                    }
                                }())
                            
                            Text("\(String(format: "%02d", currentMinutes)):\(String(format: "%02d", currentSeconds))")
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                            
                            Text("Set \(currentSet)/\(sets)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundStyle(.black)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                    
                Spacer()
                    
                VStack(spacing: 12) {
                    if !isTimerCompleted {
                        Button {
                            if isTimerRunning {
                                pauseTimer()
                            } else {
                                startTimer()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                                    .font(.title3)
                                
                                Text(isTimerRunning ? "Pause Timer" : "Start Timer")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: isTimerRunning ? [.blue, .blue] : [.green, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: (isTimerRunning ? Color.orange : Color.green).opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        
                        Button {
                            resetTimer()
                        } label : {
                            Text("Reset Timer")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            resetTimer()
                        } label : {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.title3)
                                
                                Text("Start Again")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                        
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Text("Modify Settings")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            prepareWarningSound()
            initializeTimer()
            requestNotificationPermission()
            setupAudioSession()
        }
        .onDisappear {
            stopTimer()
            stopWarningSound()
        }
        .onChange(of: scenePhase) {_, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func setupAudioSession() {
        AudioManager.shared.setupAudioSession()
    }
    
    private func prepareWarningSound() {
        warningSoundDuration = AudioManager.shared.prepareSound(named: "notification", withExtension: "mp3")
        print("Warning sound duration: \(warningSoundDuration) seconds")
    }
    
    private func playWarningSound() {
        warningTriggered = true
        
        // Play the sound using AudioManager
        let success = AudioManager.shared.playSound()
        
        if success {
            print("Warning sound played for set \(currentSet)")
        } else {
            print("Failed to play warning sound for set \(currentSet)")
        }
    }
    
    private func stopWarningSound() {
        AudioManager.shared.stopSound()
        warningTriggered = false
    }
    
    private func checkAndPlayWarningSound() {
        // If we're not at the final seconds of a set or warning already triggered, do nothing
        if warningTriggered || isTimerCompleted {
            return
        }
        
        // Calculate remaining time in current set
        let remainingSeconds = currentMinutes * 60 + currentSeconds
        
        // If remaining time equals our warning threshold, play the sound
        if remainingSeconds == warningSoundDuration {
            playWarningSound()
        }
    }
    
    private func initializeTimer() {
        currentMinutes = minutes
        currentSeconds = seconds
        currentSet = 1
        isTimerRunning = false
        isTimerCompleted = false
        isCurrentIntensityLow = isLowIntensity
        warningTriggered = false
        lowIntensityCompleted = false
        highIntensityCompleted = false
        backgroundWarningTimes = []
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
            
        isTimerRunning = true
        lastActiveTimestamp = Date()
        warningTriggered = false
        backgroundWarningTimes = []
            
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimer()
        }
    }
    
    private func updateTimer() {
        checkAndPlayWarningSound()
        
        if currentSeconds > 0 {
            currentSeconds -= 1
        } else if currentMinutes > 0 {
            currentMinutes -= 1
            currentSeconds = 59
        } else {
            if isCurrentIntensityLow {
                lowIntensityCompleted = true
            } else {
                highIntensityCompleted = true
            }
            if lowIntensityCompleted && highIntensityCompleted {
                if currentSet < sets {
                    currentSet += 1
                    lowIntensityCompleted = false
                    highIntensityCompleted = false
                } else {
                    completeTimer()
                }
            }
            currentMinutes = minutes
            currentSeconds = seconds
            isCurrentIntensityLow.toggle()
            warningTriggered = false
        }
    }
    
    private func pauseTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
        endBackgroundTask()
    }
    
    private func stopTimer() {
        isTimerRunning = false
        timer?.invalidate()
        timer = nil
        backgroundCheckTimer?.invalidate()
        backgroundCheckTimer = nil
        stopWarningSound()
        endBackgroundTask()
        cancelPendingNotifications()
    }
    
    private func resetTimer() {
        stopTimer()
        initializeTimer()
    }
    
    private func completeTimer() {
        stopTimer()
        isTimerCompleted = true
        
        if UIApplication.shared.applicationState == .background {
            sendLocalNotification(
                title: "Workout Complete!",
                body: "You've completed all \(sets) sets. Great job!"
            )
        } else {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
            case .active:
                // App came to foreground
                if isTimerRunning && !isTimerCompleted {
                    // Stop background timer if it exists
                    backgroundCheckTimer?.invalidate()
                    backgroundCheckTimer = nil
                    backgroundWarningTimes = []
                    
                    adjustTimerForBackgroundTime()
                    cancelPendingNotifications()
                    
                    // Restart the timer if it's still supposed to be running
                    if !isTimerCompleted && currentSet <= sets {
                        startTimer()
                    }
                }
                
                // Ensure audio session is active when returning to foreground
                setupAudioSession()
                
                // End background task if it exists
                endBackgroundTask()
                
            case .background:
                // App went to background
                if isTimerRunning && !isTimerCompleted {
                    // Record the exact time we went to background
                    lastActiveTimestamp = Date()
                    // Pause the active timer
                    timer?.invalidate()
                    timer = nil
                    
                    beginBackgroundTask()
                    scheduleBackgroundWarnings()
                    
                    // Only schedule completion notification
                    scheduleCompletionNotification()
                }
            case .inactive:
                // App is transitioning between states - do nothing
                break
            @unknown default:
                break
        }
    }
    
    private func scheduleBackgroundWarnings() {
        // Clear any existing scheduled warnings
        backgroundWarningTimes = []
        backgroundCheckTimer?.invalidate()
        
        let now = Date()
        
        // Calculate current remaining time
        let currentRemainingSeconds = currentMinutes * 60 + currentSeconds
        
        // If there's enough time left in the current phase to play a warning
        if currentRemainingSeconds > warningSoundDuration {
            let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
            backgroundWarningTimes.append(warningTime)
            print("Scheduled warning for current phase at \(warningTime)")
        }
        
        // Track time offset for future warnings
        var timeOffset = TimeInterval(currentRemainingSeconds)
        
        // Calculate how many more phases we need to go through
        var remainingPhases = 0
        
        // Current set phases
        if isCurrentIntensityLow {
            // We're in low phase, so we'll need the high phase too
            remainingPhases += 1
        }
        
        // Add two phases for each remaining set (low and high)
        remainingPhases += (sets - currentSet) * 2
        
        // Schedule warnings for all future phases
        var currentPhaseIsLow = isCurrentIntensityLow
        
        for _ in 0..<remainingPhases {
            // Move to next phase
            currentPhaseIsLow.toggle()
            timeOffset += TimeInterval(totalSeconds)
            
            // Schedule warning for this phase
            if timeOffset > TimeInterval(warningSoundDuration) {
                let warningTime = now.addingTimeInterval(timeOffset - TimeInterval(warningSoundDuration))
                backgroundWarningTimes.append(warningTime)
                print("Scheduled warning for future phase at \(warningTime)")
            }
        }
        
        // Log scheduled warning times
        print("Scheduled \(backgroundWarningTimes.count) warning sounds:")
        for (index, time) in backgroundWarningTimes.enumerated() {
            let timeInterval = time.timeIntervalSince(now)
            print("Warning \(index + 1): \(timeInterval) seconds from now")
        }
        
        // Start a timer that checks frequently if it's time to play a warning sound
        backgroundCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [self] _ in
            checkBackgroundWarnings()
        }
        
        // Make sure the timer runs even when app is in background
        if let timer = backgroundCheckTimer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func checkBackgroundWarnings() {
        // Add debug logging here
        print("Current set: \(currentSet)/\(sets), Phase: \(isCurrentIntensityLow ? "Low" : "High"), Low completed: \(lowIntensityCompleted), High completed: \(highIntensityCompleted)")
        print("Remaining warnings: \(backgroundWarningTimes.count)")
        
        guard !backgroundWarningTimes.isEmpty else { return }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        // Check each scheduled warning time
        for (index, warningTime) in backgroundWarningTimes.enumerated() {
            // If the time has passed or is very close (within 0.5 seconds)
            if now >= warningTime || now.timeIntervalSince(warningTime) > -0.5 {
                // Ensure audio session is active before playing
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                // Play the warning sound
                playWarningSound()
                print("Playing scheduled warning sound \(index + 1) at \(now)")
                
                // Mark this index for removal
                triggeredIndices.append(index)
                
                // Only play one sound at a time to avoid overlap
                break
            }
        }
        
        // Remove triggered warnings (in reverse order to avoid index issues)
        for index in triggeredIndices.sorted(by: >) {
            if index < backgroundWarningTimes.count {
                backgroundWarningTimes.remove(at: index)
            }
        }
        
        // If all warnings have been played, stop the check timer
        if backgroundWarningTimes.isEmpty {
            print("All warnings played, stopping background check timer")
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
        }
    }
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
        
        // Request background execution time
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [self] in
            // Time expired - end the task
            print("Background task expired")
            endBackgroundTask()
        }
        
        print("Started background task with ID: \(backgroundTaskID.rawValue)")
        
        // Ensure audio session is active for background playback
        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session activated for background task")
        } catch {
            print("Failed to activate audio session for background: \(error.localizedDescription)")
        }
        
        // Set up periodic audio session refresh
        setupBackgroundAudioRefresh()
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            print("Ending background task with ID: \(backgroundTaskID.rawValue)")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    private func adjustTimerForBackgroundTime() {
        let now = Date()
        let elapsedTime = Int(now.timeIntervalSince(lastActiveTimestamp))
        
        guard elapsedTime > 0 && elapsedTime < 3600 else {
            lastActiveTimestamp = now
            return
        }
        
        var remainingTimeToProcess = elapsedTime
        var currentSetNumber = currentSet
        var currentMin = currentMinutes
        var currentSec = currentSeconds
        var currentIntens = isCurrentIntensityLow
        var lowPhaseCompleted = lowIntensityCompleted
        var highPhaseCompleted = highIntensityCompleted
        
        while remainingTimeToProcess > 0 && currentSetNumber <= sets {
            let currentIntervalRemaining = currentMin * 60 + currentSec
            
            if remainingTimeToProcess >= currentIntervalRemaining {
                // This interval is completed
                remainingTimeToProcess -= currentIntervalRemaining
                
                if currentIntens {
                    lowPhaseCompleted = true
                } else {
                    highPhaseCompleted = true
                }
                
                if lowPhaseCompleted && highPhaseCompleted {
                    if currentSetNumber < sets {
                        currentSetNumber += 1
                        lowPhaseCompleted = false
                        highPhaseCompleted = false
                    } else {
                        currentSetNumber = sets // This ensures we know it's completed
                        currentMin = 0
                        currentSec = 0
                        remainingTimeToProcess = 0 // Stop processing
                        break
                    }
                }
                currentMin = minutes
                currentSec = seconds
                currentIntens.toggle()
                
            } else {
                // Partial completion of current interval
                let newRemainingSeconds = currentIntervalRemaining - remainingTimeToProcess
                currentMin = newRemainingSeconds / 60
                currentSec = newRemainingSeconds % 60
                remainingTimeToProcess = 0
            }
        }
        
        currentSet = currentSetNumber
        currentMinutes = max(0, currentMin)
        currentSeconds = max(0, currentSec)
        isCurrentIntensityLow = currentIntens
        lowIntensityCompleted = lowPhaseCompleted
        highIntensityCompleted = highPhaseCompleted
        warningTriggered = false // Reset warning flag after background time
            
        // If we've completed all sets
        if currentSet > sets  || (currentSet == sets && lowIntensityCompleted && highIntensityCompleted) {
            isTimerCompleted = true
            isTimerRunning = false
            currentMinutes = 0
            currentSeconds = 0
        }
        
        lastActiveTimestamp = now
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
            
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        )
            
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleCompletionNotification() {
        
        let currentPhaseTimeRemaining = currentMinutes * 60 + currentSeconds
        
        var totalRemainingSeconds = currentPhaseTimeRemaining
        
        if isCurrentIntensityLow && !lowIntensityCompleted {
            totalRemainingSeconds += totalSeconds
        } else if !isCurrentIntensityLow && !highIntensityCompleted {

        }
        
        // Add time for remaining full sets
        let completeSetsRemaining = sets - currentSet
        if completeSetsRemaining > 0 {
            // Each remaining set has two phases (low and high intensity)
            totalRemainingSeconds += completeSetsRemaining * totalSeconds * 2
        }
        
        // Schedule final completion notification
        if totalRemainingSeconds > 0 {
            let content = UNMutableNotificationContent()
            content.title = "Workout Complete!"
            content.body = "You've completed all \(sets) sets. Great job!"
            content.sound = .default
            
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(totalRemainingSeconds),
                repeats: false
            )
            
            let request = UNNotificationRequest(
                identifier: "workoutComplete",
                content: content,
                trigger: trigger
            )
            
            print("Scheduling completion notification in \(totalRemainingSeconds) seconds")
            UNUserNotificationCenter.current().add(request)
        }
    }
    
    private func setupBackgroundAudioRefresh() {
        // Create a timer that periodically reactivates the audio session
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            if self.isTimerRunning && !self.isTimerCompleted {
                do {
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    print("Periodically reactivated audio session")
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
            }
        }
    }
        
    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

#Preview {
    TimerRunView(minutes: 0, seconds: 10, sets: 2, isLowIntensity: true, totalWorkoutMinutes: 0, totalWorkoutSeconds: 0)
}
