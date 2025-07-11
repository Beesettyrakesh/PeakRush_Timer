// File: PeakRush_Timer/Services/AudioManager.swift

import Foundation
import AVFoundation
import AVFAudio

class AudioManager: NSObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer: AVSpeechSynthesizer?
    private var wasPlayingWhenInterrupted = false
    private var currentSoundURL: URL?
    private var audioPlaybackPosition: TimeInterval = 0
    private var isAudioCuePlaying = false
    private var isSpeechPlaying = false
    
    // Notification observer
    private var interruptionObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        setupNotifications()
        speechSynthesizer = AVSpeechSynthesizer()
        speechSynthesizer?.delegate = self
    }
    
    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    func setupAudioSession() {
        do {
            // Configure audio session for mixing with other audio
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            
            print("Audio session configured for background playback with mixing")
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            
            // Retry with simpler configuration if the first attempt fails
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback)
                try AVAudioSession.sharedInstance().setActive(true)
                print("Audio session configured with fallback settings")
            } catch {
                print("Failed to set up audio session with fallback settings: \(error.localizedDescription)")
            }
        }
    }
    
    private func setupNotifications() {
        // Register for audio session interruption notifications
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAudioInterruption(notification)
        }
    }
    
    private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Interruption began (e.g., phone call or other app started playing audio)
            wasPlayingWhenInterrupted = audioPlayer?.isPlaying ?? false
            if wasPlayingWhenInterrupted {
                // Save current playback position
                audioPlaybackPosition = audioPlayer?.currentTime ?? 0
                audioPlayer?.pause()
                print("Audio interrupted - paused playback at position \(audioPlaybackPosition)")
            }
            
            // Also handle speech interruption
            if speechSynthesizer?.isSpeaking == true {
                speechSynthesizer?.pauseSpeaking(at: .immediate)
                print("Speech interrupted - paused speaking")
            }
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            // If we should resume and we were playing before
            if options.contains(.shouldResume) {
                do {
                    // Reactivate audio session if needed
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    
                    // Resume playback from saved position if we were playing
                    if wasPlayingWhenInterrupted, let player = audioPlayer {
                        player.currentTime = audioPlaybackPosition
                        player.play()
                        print("Audio interruption ended - resumed playback from position \(audioPlaybackPosition)")
                    }
                    
                    // Resume speech if it was interrupted
                    if speechSynthesizer?.isSpeaking == false && isSpeechPlaying {
                        speechSynthesizer?.continueSpeaking()
                        print("Speech interruption ended - resumed speaking")
                    }
                } catch {
                    print("Failed to reactivate audio session: \(error.localizedDescription)")
                }
            }
            
        @unknown default:
            break
        }
    }
    
    func prepareSound(named filename: String, withExtension ext: String) -> Int {
        guard let soundURL = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("Sound file \(filename).\(ext) not found")
            return 5 // Default duration if sound file not found
        }
        
        currentSoundURL = soundURL
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.delegate = self
            
            // Calculate the duration of the sound file in seconds
            let duration = audioPlayer?.duration ?? 0
            return Int(ceil(duration))
        } catch {
            print("Failed to prepare audio player: \(error.localizedDescription)")
            return 5 // Default duration if there's an error
        }
    }
    
    func playSound() -> Bool {
        // Ensure audio session is active with retry mechanism
        var audioSessionActive = false
        for attempt in 1...3 {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                audioSessionActive = true
                if attempt > 1 {
                    print("Audio session activated on attempt \(attempt)")
                }
                break
            } catch {
                print("Failed to activate audio session (attempt \(attempt)): \(error.localizedDescription)")
                // Short delay before retry
                if attempt < 3 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
        
        if !audioSessionActive {
            print("Failed to activate audio session after multiple attempts")
            return false
        }
        
        // If we don't have a prepared player but have a URL, try to create one
        if audioPlayer == nil, let url = currentSoundURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.delegate = self
                // Set volume to maximum for better audibility in background
                audioPlayer?.volume = 1.0
            } catch {
                print("Failed to recreate audio player: \(error.localizedDescription)")
                return false
            }
        }
        
        // If audio is already playing, don't restart it
        if audioPlayer?.isPlaying == true {
            print("Warning sound is already playing, not restarting")
            return true
        }
        
        // Play the sound from the beginning
        audioPlayer?.currentTime = 0
        audioPlaybackPosition = 0
        isAudioCuePlaying = true
        
        // Try to play with retry mechanism
        var playSuccess = false
        for attempt in 1...3 {
            if let player = audioPlayer {
                playSuccess = player.play()
                if playSuccess {
                    if attempt > 1 {
                        print("Warning sound started playing successfully on attempt \(attempt)")
                    } else {
                        print("Warning sound started playing successfully")
                    }
                    break
                } else {
                    print("Failed to play warning sound (attempt \(attempt))")
                    // Short delay before retry
                    if attempt < 3 {
                        Thread.sleep(forTimeInterval: 0.1)
                        // Try to reactivate audio session before retry
                        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    }
                }
            }
        }
        
        if !playSuccess {
            print("Failed to play warning sound after multiple attempts")
            isAudioCuePlaying = false
        }
        
        return playSuccess
    }
    
    func stopSound() {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
            audioPlaybackPosition = 0
            isAudioCuePlaying = false
            print("Warning sound stopped")
        }
    }
    
    func isPlaying() -> Bool {
        return audioPlayer?.isPlaying ?? false
    }
    
    func getRemainingPlaybackTime() -> TimeInterval {
        guard let player = audioPlayer else { return 0 }
        return player.duration - player.currentTime
    }
    
    func pauseSound() {
        if audioPlayer?.isPlaying == true {
            audioPlaybackPosition = audioPlayer?.currentTime ?? 0
            audioPlayer?.pause()
            print("Warning sound paused at position \(audioPlaybackPosition)")
        }
    }
    
    func resumeSound() -> Bool {
        if !isAudioCuePlaying {
            return false
        }
        
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
            return false
        }
        
        // If we have a player and it's not playing, resume from saved position
        if let player = audioPlayer, !player.isPlaying {
            player.currentTime = audioPlaybackPosition
            let success = player.play()
            
            if success {
                print("Warning sound resumed from position \(audioPlaybackPosition)")
            } else {
                print("Failed to resume warning sound")
                isAudioCuePlaying = false
            }
            
            return success
        }
        
        return false
    }
    
    // Method for speaking text
    func speakText(_ text: String, rate: Float = 0.3, pitch: Float = 1.0, completion: (() -> Void)? = nil) -> Bool {
        // Ensure audio session is active with retry mechanism
        var audioSessionActive = false
        for attempt in 1...3 {
            do {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                audioSessionActive = true
                if attempt > 1 {
                    print("Audio session activated for speech on attempt \(attempt)")
                }
                break
            } catch {
                print("Failed to activate audio session for speech (attempt \(attempt)): \(error.localizedDescription)")
                // Short delay before retry
                if attempt < 3 {
                    Thread.sleep(forTimeInterval: 0.1)
                }
            }
        }
        
        if !audioSessionActive {
            print("Failed to activate audio session for speech after multiple attempts")
            return false
        }
        
        // Create utterance with the text
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate      // 0.0 (slowest) to 1.0 (fastest)
        utterance.pitchMultiplier = pitch  // 0.5 (low pitch) to 2.0 (high pitch)
        utterance.volume = 1.0     // 0.0 (silent) to 1.0 (loudest)
        
        let voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.voice = voice
        print("Using standard en-US voice for speech")
        
        // Add pre-speech silence to ensure audio session is fully active
        utterance.preUtteranceDelay = 0.1
        
        // Store completion handler if provided
        if let completion = completion {
            speechCompletionHandler = completion
        } else {
            speechCompletionHandler = nil
        }
        
        // Start speaking with retry mechanism
        isSpeechPlaying = true
        var attemptSucceeded = false
        
        for attempt in 1...2 {
            if let synthesizer = speechSynthesizer {
                synthesizer.speak(utterance)
                // Since speak() returns Void, we'll assume it started successfully
                // unless we detect otherwise
                attemptSucceeded = true
                
                if attempt > 1 {
                    print("Started speaking on attempt \(attempt): \(text)")
                } else {
                    print("Started speaking: \(text)")
                }
                break
            } else {
                print("Failed to start speech (attempt \(attempt)) - synthesizer is nil")
                // Short delay before retry
                if attempt < 2 {
                    Thread.sleep(forTimeInterval: 0.2)
                    // Try to reactivate audio session before retry
                    try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                }
            }
        }
        
        if !attemptSucceeded {
            print("Failed to start speech after multiple attempts")
            isSpeechPlaying = false
        }
        
        return attemptSucceeded
    }
    
    func stopSpeech() {
        if speechSynthesizer?.isSpeaking == true {
            speechSynthesizer?.stopSpeaking(at: .immediate)
            isSpeechPlaying = false
            print("Speech stopped")
            
            // Clear completion handler
            speechCompletionHandler = nil
        }
    }
    
    func isSpeaking() -> Bool {
        return speechSynthesizer?.isSpeaking ?? false
    }
    
    // Method to check if any audio is playing (either speech or sound)
    func isAnyAudioPlaying() -> Bool {
        let playing = isPlaying() || isSpeaking()
        
        // If we think audio is playing but the audio player or speech synthesizer disagrees,
        // update our internal state to match reality
        if isAudioCuePlaying && !isPlaying() {
            isAudioCuePlaying = false
        }
        
        if isSpeechPlaying && !isSpeaking() {
            isSpeechPlaying = false
        }
        
        return playing
    }
    
    // Method to ensure audio session is active for background operation
    func ensureAudioSessionActive() -> Bool {
        do {
            // Check if audio session is already active
            if !AVAudioSession.sharedInstance().isOtherAudioPlaying {
                try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                print("Audio session reactivated for background operation")
            }
            return true
        } catch {
            print("Failed to ensure audio session is active: \(error.localizedDescription)")
            return false
        }
    }
    
    // Property to store speech completion handler
    private var speechCompletionHandler: (() -> Void)?
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player finished playing, success: \(flag)")
        audioPlaybackPosition = 0
        isAudioCuePlaying = false
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio player decode error: \(error.localizedDescription)")
        }
        isAudioCuePlaying = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Speech synthesis finished")
        isSpeechPlaying = false
        
        // Call completion handler if set
        if let completion = speechCompletionHandler {
            DispatchQueue.main.async {
                completion()
            }
            speechCompletionHandler = nil
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Speech synthesis cancelled")
        isSpeechPlaying = false
        speechCompletionHandler = nil
    }
}
