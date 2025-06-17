import SwiftUI
import UserNotifications
import AVFoundation

struct TimerRunView: View {
    let minutes: Int
    let seconds: Int
    let sets: Int
    let isLowIntensity: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var currentMinutes: Int = 0
    @State private var currentSeconds: Int = 0
    @State private var currentSet: Int = 0
    @State private var isTimerRunning: Bool = false
    @State private var timer: Timer?
    @State private var isTimerCompleted: Bool = false
    @State private var currentIntensity: Bool = true
    
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
            if currentIntensity {
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
            return currentIntensity ? "Low Intensity" : "High Intensity"
        }
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
                        
                    VStack(spacing: 4) {
                        Text("PeakRush")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                        
                    Spacer()
                    
                    Button {} label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                            Text("Back")
                                .font(.subheadline)
                        }
                        .foregroundStyle(.clear)
                    }
                    .disabled(true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                    
                HStack(spacing: 12) {
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                
                            Text("INTERVAL")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                            
                        Text("\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))")
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "repeat")
                                .font(.title3)
                                .foregroundStyle(.green)
                                
                            Text("SETS")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .tracking(0.5)
                        }
                            
                        Text("\(sets)")
                            .font(.system(size: 22, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray), lineWidth: 8)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .stroke(circleColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 250, height: 250)
                    
                    VStack(spacing: 8) {
                        Image(systemName: currentIntensity ? "figure.walk" : "figure.run")
                            .font(.largeTitle)
                            .foregroundStyle({
                                if isTimerCompleted {
                                    Color.blue
                                } else if !isTimerRunning {
                                    Color.gray
                                } else {
                                    currentIntensity ? Color.green : Color.red
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
                                    colors: isTimerRunning ? [.blue, .cyan] : [.green, .green],
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
            prepareWarningSound() // First prepare the sound to get its duration
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
    
    // MARK: - Audio Functions
    
    private func setupAudioSession() {
        do {
            // Configure audio session for background playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            print("Audio session configured for background playback")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func prepareWarningSound() {
        guard let soundURL = Bundle.main.url(forResource: "notification", withExtension: "mp3") else {
            print("Warning sound file not found")
            // Set a default duration if sound file not found
            warningSoundDuration = 5
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            
            // Calculate the duration of the sound file in seconds
            let duration = audioPlayer?.duration ?? 0
            warningSoundDuration = Int(ceil(duration))
            
            print("Warning sound duration: \(warningSoundDuration) seconds")
            
            audioPlayer?.prepareToPlay()
            audioPlayer?.numberOfLoops = 0 // Play once
            
            // Add completion handler
            audioPlayer?.delegate = AudioPlayerDelegate.shared
        } catch {
            print("Failed to prepare audio player: \(error.localizedDescription)")
            // Set a default duration if there's an error
            warningSoundDuration = 5
        }
    }
    
    private func playWarningSound() {
        // Reset warning flag when playing
        warningTriggered = true
        
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
        }
        
        // Play the sound
        audioPlayer?.currentTime = 0
        audioPlayer?.play()
        
        print("Warning sound played for set \(currentSet)")
    }
    
    private func stopWarningSound() {
        audioPlayer?.stop()
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
        currentIntensity = isLowIntensity
        warningTriggered = false
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
        // Check if we need to play warning sound
        checkAndPlayWarningSound()
        
        if currentSeconds > 0 {
            currentSeconds -= 1
        } else if currentMinutes > 0 {
            currentMinutes -= 1
            currentSeconds = 59
        } else {
            if currentSet < sets {
                _ = currentSet
                currentSet += 1
                currentMinutes = minutes
                currentSeconds = seconds
                currentIntensity.toggle()
                warningTriggered = false // Reset warning flag for next set
            } else {
                completeTimer()
            }
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
    
    // Schedule all warning sounds for background playback
    private func scheduleBackgroundWarnings() {
        // Clear any existing scheduled warnings
        backgroundWarningTimes = []
        backgroundCheckTimer?.invalidate()
        
        // Calculate current remaining time
        let currentRemainingSeconds = currentMinutes * 60 + currentSeconds
        let now = Date()
        
        // If there's enough time left in the current set to play a warning
        if currentRemainingSeconds > warningSoundDuration {
            let warningTime = now.addingTimeInterval(TimeInterval(currentRemainingSeconds - warningSoundDuration))
            backgroundWarningTimes.append(warningTime)
        }
        
        // Calculate warning times for future sets
        var timeOffset = TimeInterval(currentRemainingSeconds)
        for setIndex in currentSet..<sets {
            // Skip the first set as we already handled it above
            if setIndex > currentSet {
                // Each set has a total duration, and we want to play the warning sound
                // warningSoundDuration seconds before the end
                let setDuration = TimeInterval(totalSeconds)
                let warningOffset = setDuration - TimeInterval(warningSoundDuration)
                
                let warningTime = now.addingTimeInterval(timeOffset + warningOffset)
                backgroundWarningTimes.append(warningTime)
                
                timeOffset += setDuration
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
    
    // Check if it's time to play any scheduled warning sounds
    private func checkBackgroundWarnings() {
        guard !backgroundWarningTimes.isEmpty else { return }
        
        let now = Date()
        var triggeredIndices: [Int] = []
        
        // Check each scheduled warning time
        for (index, warningTime) in backgroundWarningTimes.enumerated() {
            // If the time has passed or is very close (within 0.5 seconds)
            if now >= warningTime || now.timeIntervalSince(warningTime) > -0.5 {
                // Play the warning sound
                playWarningSound()
                print("Playing scheduled warning sound \(index + 1)")
                
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
            backgroundCheckTimer?.invalidate()
            backgroundCheckTimer = nil
            
            // End the background task if we're done with all warnings
            if currentSet >= sets {
                endBackgroundTask()
            }
        }
    }
    
    private func beginBackgroundTask() {
        // End any existing background task
        endBackgroundTask()
            
        // Start a new background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [self] in
            // Time expired - end the task
            print("Background task expired")
            endBackgroundTask()
        }
        
        print("Started background task with ID: \(backgroundTaskID.rawValue)")
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
        
        guard elapsedTime > 0 && elapsedTime < 3600 else { // Max 1 hour
            lastActiveTimestamp = now
            return
        }
        
        var remainingTimeToProcess = elapsedTime
        var currentSetNumber = currentSet
        var currentMin = currentMinutes
        var currentSec = currentSeconds
        var currentIntens = currentIntensity
        
        while remainingTimeToProcess > 0 && currentSetNumber <= sets {
            let currentIntervalRemaining = currentMin * 60 + currentSec
            
            if remainingTimeToProcess >= currentIntervalRemaining {
                // This interval is completed
                remainingTimeToProcess -= currentIntervalRemaining
                
                // Move to next set
                if currentSetNumber < sets {
                    currentSetNumber += 1
                    currentMin = minutes
                    currentSec = seconds
                    currentIntens.toggle() // Alternate intensity
                } else {
                    // All sets completed
                    currentSetNumber = sets // This ensures we know it's completed
                    currentMin = 0
                    currentSec = 0
                    remainingTimeToProcess = 0 // Stop processing
                    break
                }
            } else {
                // Partial completion of current interval
                let newRemainingSeconds = currentIntervalRemaining - remainingTimeToProcess
                currentMin = newRemainingSeconds / 60
                currentSec = newRemainingSeconds % 60
                remainingTimeToProcess = 0
            }
        }
        
        currentSet = currentSetNumber
        currentMinutes = max(0, currentMin) // Ensure non-negative
        currentSeconds = max(0, currentSec) // Ensure non-negative
        currentIntensity = currentIntens
        warningTriggered = false // Reset warning flag after background time
            
        // If we've completed all sets
        if currentSet > sets {
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
        // Only schedule the final completion notification
        let currentIntervalRemaining = currentMinutes * 60 + currentSeconds
        let remainingSets = sets - currentSet
        let totalRemainingSeconds = currentIntervalRemaining + (remainingSets * totalSeconds)
        
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
            
            UNUserNotificationCenter.current().add(request)
        }
    }
        
    private func cancelPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Audio Player Delegate
class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayerDelegate()
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player finished playing")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio player decode error: \(error.localizedDescription)")
        }
    }
}

#Preview {
    TimerRunView(minutes: 0, seconds: 10, sets: 2, isLowIntensity: true)
}
