import Foundation
import AVFoundation

class AudioManager: NSObject {
    static let shared = AudioManager()
    
    private var audioPlayer: AVAudioPlayer?
    private var wasPlayingWhenInterrupted = false
    private var currentSoundURL: URL?
    
    // Notification observer
    private var interruptionObserver: NSObjectProtocol?
    
    override init() {
        super.init()
        setupNotifications()
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
            audioPlayer?.pause()
            print("Audio interrupted - paused playback")
            
        case .ended:
            // Interruption ended
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            // If we should resume and we were playing before
            if options.contains(.shouldResume) && wasPlayingWhenInterrupted {
                do {
                    // Reactivate audio session if needed
                    try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
                    
                    // Resume playback
                    audioPlayer?.play()
                    print("Audio interruption ended - resumed playback")
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
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error.localizedDescription)")
            return false
        }
        
        // If we don't have a prepared player but have a URL, try to create one
        if audioPlayer == nil, let url = currentSoundURL {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                audioPlayer?.delegate = self
            } catch {
                print("Failed to recreate audio player: \(error.localizedDescription)")
                return false
            }
        }
        
        // Play the sound
        audioPlayer?.currentTime = 0
        let success = audioPlayer?.play() ?? false
        
        if success {
            print("Warning sound played successfully")
        } else {
            print("Failed to play warning sound")
        }
        
        return success
    }
    
    func stopSound() {
        audioPlayer?.stop()
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("Audio player finished playing, success: \(flag)")
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Audio player decode error: \(error.localizedDescription)")
        }
    }
}
