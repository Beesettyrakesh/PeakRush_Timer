import Foundation

struct TimerModel {
    // Configuration parameters
    var minutes: Int
    var seconds: Int
    var sets: Int
    var isLowIntensity: Bool
    
    // Computed properties
    var totalSeconds: Int {
        return minutes * 60 + seconds
    }
    
    var totalWorkoutDuration: Int {
        return totalSeconds * 2 * sets
    }
    
    var totalWorkoutMinutes: Int {
        return totalWorkoutDuration / 60
    }
    
    var totalWorkoutSeconds: Int {
        return totalWorkoutDuration % 60
    }
    
    // Runtime state
    var currentMinutes: Int
    var currentSeconds: Int
    var currentSet: Int
    var isCurrentIntensityLow: Bool
    var lowIntensityCompleted: Bool
    var highIntensityCompleted: Bool
    var isTimerRunning: Bool
    var isTimerCompleted: Bool
    var warningTriggered: Bool
    
    // Initialize with default values
    init(minutes: Int = 0, seconds: Int = 0, sets: Int = 0, isLowIntensity: Bool = true) {
        self.minutes = minutes
        self.seconds = seconds
        self.sets = sets
        self.isLowIntensity = isLowIntensity
        
        // Initialize runtime state
        self.currentMinutes = minutes
        self.currentSeconds = seconds
        self.currentSet = 1
        self.isCurrentIntensityLow = isLowIntensity
        self.lowIntensityCompleted = false
        self.highIntensityCompleted = false
        self.isTimerRunning = false
        self.isTimerCompleted = false
        self.warningTriggered = false
    }
    
    var isConfigurationValid: Bool {
        return sets > 0 && (minutes > 0 || seconds > 0)
    }
    
    var currentTotalSeconds: Int {
        return currentMinutes * 60 + currentSeconds
    }
    
    var isSetCompleted: Bool {
        return lowIntensityCompleted && highIntensityCompleted
    }
}
