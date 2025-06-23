import Foundation
import SwiftUI

class TimerConfigViewModel: ObservableObject {
    @Published var timerModel = TimerModel()
    
    var minutes: Binding<Int> {
        Binding(
            get: { self.timerModel.minutes },
            set: { self.timerModel.minutes = $0 }
        )
    }
    
    var seconds: Binding<Int> {
        Binding(
            get: { self.timerModel.seconds },
            set: { self.timerModel.seconds = $0 }
        )
    }
    
    var sets: Binding<Int> {
        Binding(
            get: { self.timerModel.sets },
            set: { self.timerModel.sets = $0 }
        )
    }
    
    var isLowIntensity: Binding<Bool> {
        Binding(
            get: { self.timerModel.isLowIntensity },
            set: { self.timerModel.isLowIntensity = $0 }
        )
    }
    
    var isConfigurationValid: Bool {
        return timerModel.isConfigurationValid
    }
    
    var totalWorkoutDuration: Int {
        return timerModel.totalWorkoutDuration
    }
    
    var totalMinutes: Int {
        return timerModel.totalWorkoutMinutes
    }
    
    var totalSeconds: Int {
        return timerModel.totalWorkoutSeconds
    }
    
    func createTimerRunViewModel() -> TimerRunViewModel {
        return TimerRunViewModel(timerModel: timerModel)
    }
}
