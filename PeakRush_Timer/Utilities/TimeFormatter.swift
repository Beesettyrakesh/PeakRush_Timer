import Foundation

struct TimeFormatter {
    static func formatTime(minutes: Int, seconds: Int) -> String {
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    static func formatSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return formatTime(minutes: minutes, seconds: seconds)
    }
}
