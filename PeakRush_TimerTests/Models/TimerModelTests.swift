import XCTest
@testable import PeakRush_Timer

class TimerModelTests: XCTestCase {
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        // When
        let model = TimerModel()
        
        // Then
        XCTAssertEqual(model.minutes, 0)
        XCTAssertEqual(model.seconds, 0)
        XCTAssertEqual(model.sets, 0)
        XCTAssertTrue(model.isLowIntensity)
        
        XCTAssertEqual(model.currentMinutes, 0)
        XCTAssertEqual(model.currentSeconds, 0)
        XCTAssertEqual(model.currentSet, 1)
        XCTAssertTrue(model.isCurrentIntensityLow)
        XCTAssertFalse(model.lowIntensityCompleted)
        XCTAssertFalse(model.highIntensityCompleted)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertFalse(model.isTimerCompleted)
        XCTAssertFalse(model.warningTriggered)
    }
    
    func testCustomInitialization() {
        // When
        let model = TimerModel(minutes: 2, seconds: 30, sets: 3, isLowIntensity: false)
        
        // Then
        XCTAssertEqual(model.minutes, 2)
        XCTAssertEqual(model.seconds, 30)
        XCTAssertEqual(model.sets, 3)
        XCTAssertFalse(model.isLowIntensity)
        
        XCTAssertEqual(model.currentMinutes, 2)
        XCTAssertEqual(model.currentSeconds, 30)
        XCTAssertEqual(model.currentSet, 1)
        XCTAssertFalse(model.isCurrentIntensityLow)
        XCTAssertFalse(model.lowIntensityCompleted)
        XCTAssertFalse(model.highIntensityCompleted)
        XCTAssertFalse(model.isTimerRunning)
        XCTAssertFalse(model.isTimerCompleted)
        XCTAssertFalse(model.warningTriggered)
    }
    
    // MARK: - Computed Properties Tests
    
    func testTotalSeconds() {
        // Given
        let model1 = TimerModel(minutes: 1, seconds: 30)
        let model2 = TimerModel(minutes: 2, seconds: 15)
        let model3 = TimerModel(minutes: 0, seconds: 45)
        
        // Then
        XCTAssertEqual(model1.totalSeconds, 90)
        XCTAssertEqual(model2.totalSeconds, 135)
        XCTAssertEqual(model3.totalSeconds, 45)
    }
    
    func testTotalWorkoutDuration() {
        // Given
        let model1 = TimerModel(minutes: 1, seconds: 0, sets: 2)
        let model2 = TimerModel(minutes: 0, seconds: 30, sets: 3)
        
        // Then
        // For model1: 60 seconds per interval * 2 phases * 2 sets = 240 seconds
        XCTAssertEqual(model1.totalWorkoutDuration, 240)
        
        // For model2: 30 seconds per interval * 2 phases * 3 sets = 180 seconds
        XCTAssertEqual(model2.totalWorkoutDuration, 180)
    }
    
    func testTotalWorkoutMinutesAndSeconds() {
        // Given
        let model1 = TimerModel(minutes: 1, seconds: 15, sets: 2)
        // Total: 75 seconds per interval * 2 phases * 2 sets = 300 seconds = 5 minutes
        
        let model2 = TimerModel(minutes: 0, seconds: 45, sets: 3)
        // Total: 45 seconds per interval * 2 phases * 3 sets = 270 seconds = 4 minutes 30 seconds
        
        // Then
        XCTAssertEqual(model1.totalWorkoutMinutes, 5)
        XCTAssertEqual(model1.totalWorkoutSeconds, 0)
        
        XCTAssertEqual(model2.totalWorkoutMinutes, 4)
        XCTAssertEqual(model2.totalWorkoutSeconds, 30)
    }
    
    // MARK: - Configuration Validation Tests
    
    func testIsConfigurationValid() {
        // Given
        let validModel1 = TimerModel(minutes: 1, seconds: 0, sets: 1)
        let validModel2 = TimerModel(minutes: 0, seconds: 30, sets: 2)
        let invalidModel1 = TimerModel(minutes: 0, seconds: 0, sets: 1)
        let invalidModel2 = TimerModel(minutes: 1, seconds: 30, sets: 0)
        
        // Then
        XCTAssertTrue(validModel1.isConfigurationValid)
        XCTAssertTrue(validModel2.isConfigurationValid)
        XCTAssertFalse(invalidModel1.isConfigurationValid)
        XCTAssertFalse(invalidModel2.isConfigurationValid)
    }
    
    // MARK: - Runtime State Tests
    
    func testCurrentTotalSeconds() {
        // Given
        var model = TimerModel(minutes: 2, seconds: 15)
        
        // Then
        XCTAssertEqual(model.currentTotalSeconds, 135)
        
        // When
        model.currentMinutes = 1
        model.currentSeconds = 30
        
        // Then
        XCTAssertEqual(model.currentTotalSeconds, 90)
    }
    
    func testIsSetCompleted() {
        // Given
        var model = TimerModel()
        
        // Then - initially both phases are not completed
        XCTAssertFalse(model.isSetCompleted)
        
        // When - only low intensity is completed
        model.lowIntensityCompleted = true
        
        // Then
        XCTAssertFalse(model.isSetCompleted)
        
        // When - only high intensity is completed
        model.lowIntensityCompleted = false
        model.highIntensityCompleted = true
        
        // Then
        XCTAssertFalse(model.isSetCompleted)
        
        // When - both phases are completed
        model.lowIntensityCompleted = true
        
        // Then
        XCTAssertTrue(model.isSetCompleted)
    }
}
