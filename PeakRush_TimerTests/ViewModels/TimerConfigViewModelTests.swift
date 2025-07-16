import XCTest
@testable import PeakRush_Timer
import SwiftUI

class TimerConfigViewModelTests: XCTestCase {
    
    var viewModel: TimerConfigViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = TimerConfigViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Binding Tests
    
    func testMinutesBinding() {
        // Given
        let initialMinutes = viewModel.timerModel.minutes
        let newMinutes = 5
        
        // When
        viewModel.minutes.wrappedValue = newMinutes
        
        // Then
        XCTAssertEqual(viewModel.timerModel.minutes, newMinutes)
        XCTAssertNotEqual(viewModel.timerModel.minutes, initialMinutes)
        
        // When - test the getter
        let retrievedMinutes = viewModel.minutes.wrappedValue
        
        // Then
        XCTAssertEqual(retrievedMinutes, newMinutes)
    }
    
    func testSecondsBinding() {
        // Given
        let initialSeconds = viewModel.timerModel.seconds
        let newSeconds = 30
        
        // When
        viewModel.seconds.wrappedValue = newSeconds
        
        // Then
        XCTAssertEqual(viewModel.timerModel.seconds, newSeconds)
        XCTAssertNotEqual(viewModel.timerModel.seconds, initialSeconds)
        
        // When - test the getter
        let retrievedSeconds = viewModel.seconds.wrappedValue
        
        // Then
        XCTAssertEqual(retrievedSeconds, newSeconds)
    }
    
    func testSetsBinding() {
        // Given
        let initialSets = viewModel.timerModel.sets
        let newSets = 3
        
        // When
        viewModel.sets.wrappedValue = newSets
        
        // Then
        XCTAssertEqual(viewModel.timerModel.sets, newSets)
        XCTAssertNotEqual(viewModel.timerModel.sets, initialSets)
        
        // When - test the getter
        let retrievedSets = viewModel.sets.wrappedValue
        
        // Then
        XCTAssertEqual(retrievedSets, newSets)
    }
    
    func testIsLowIntensityBinding() {
        // Given
        let initialValue = viewModel.timerModel.isLowIntensity
        let newValue = !initialValue
        
        // When
        viewModel.isLowIntensity.wrappedValue = newValue
        
        // Then
        XCTAssertEqual(viewModel.timerModel.isLowIntensity, newValue)
        XCTAssertNotEqual(viewModel.timerModel.isLowIntensity, initialValue)
        
        // When - test the getter
        let retrievedValue = viewModel.isLowIntensity.wrappedValue
        
        // Then
        XCTAssertEqual(retrievedValue, newValue)
    }
    
    // MARK: - Computed Properties Tests
    
    func testIsConfigurationValid() {
        // Given - invalid configuration (default)
        
        // Then
        XCTAssertFalse(viewModel.isConfigurationValid)
        
        // When - set valid configuration
        viewModel.timerModel.minutes = 1
        viewModel.timerModel.sets = 1
        
        // Then
        XCTAssertTrue(viewModel.isConfigurationValid)
        
        // When - set invalid configuration
        viewModel.timerModel.minutes = 0
        viewModel.timerModel.seconds = 0
        
        // Then
        XCTAssertFalse(viewModel.isConfigurationValid)
        
        // When - set another valid configuration
        viewModel.timerModel.seconds = 30
        
        // Then
        XCTAssertTrue(viewModel.isConfigurationValid)
    }
    
    func testTotalWorkoutDuration() {
        // Given
        viewModel.timerModel.minutes = 1
        viewModel.timerModel.seconds = 30
        viewModel.timerModel.sets = 2
        
        // Then
        // 90 seconds per interval * 2 phases * 2 sets = 360 seconds
        XCTAssertEqual(viewModel.totalWorkoutDuration, 360)
        
        // When
        viewModel.timerModel.minutes = 0
        viewModel.timerModel.seconds = 45
        viewModel.timerModel.sets = 3
        
        // Then
        // 45 seconds per interval * 2 phases * 3 sets = 270 seconds
        XCTAssertEqual(viewModel.totalWorkoutDuration, 270)
    }
    
    func testTotalMinutesAndSeconds() {
        // Given
        viewModel.timerModel.minutes = 1
        viewModel.timerModel.seconds = 15
        viewModel.timerModel.sets = 2
        
        // Then
        // 75 seconds per interval * 2 phases * 2 sets = 300 seconds = 5 minutes
        XCTAssertEqual(viewModel.totalMinutes, 5)
        XCTAssertEqual(viewModel.totalSeconds, 0)
        
        // When
        viewModel.timerModel.minutes = 0
        viewModel.timerModel.seconds = 45
        viewModel.timerModel.sets = 3
        
        // Then
        // 45 seconds per interval * 2 phases * 3 sets = 270 seconds = 4 minutes 30 seconds
        XCTAssertEqual(viewModel.totalMinutes, 4)
        XCTAssertEqual(viewModel.totalSeconds, 30)
    }
    
    // MARK: - Factory Method Tests
    
    func testCreateTimerRunViewModel() {
        // Given
        viewModel.timerModel.minutes = 2
        viewModel.timerModel.seconds = 30
        viewModel.timerModel.sets = 3
        viewModel.timerModel.isLowIntensity = false
        
        // When
        let timerRunViewModel = viewModel.createTimerRunViewModel()
        
        // Then
        XCTAssertEqual(timerRunViewModel.timerModel.minutes, 2)
        XCTAssertEqual(timerRunViewModel.timerModel.seconds, 30)
        XCTAssertEqual(timerRunViewModel.timerModel.sets, 3)
        XCTAssertFalse(timerRunViewModel.timerModel.isLowIntensity)
        
        // Verify that the runtime state is properly initialized
        XCTAssertEqual(timerRunViewModel.timerModel.currentMinutes, 2)
        XCTAssertEqual(timerRunViewModel.timerModel.currentSeconds, 30)
        XCTAssertEqual(timerRunViewModel.timerModel.currentSet, 1)
        XCTAssertFalse(timerRunViewModel.timerModel.isCurrentIntensityLow)
        XCTAssertFalse(timerRunViewModel.timerModel.isTimerRunning)
        XCTAssertFalse(timerRunViewModel.timerModel.isTimerCompleted)
    }
}
