import XCTest
@testable import PeakRush_Timer

class TimeFormatterTests: XCTestCase {
    
    // MARK: - formatTime Tests
    
    func testFormatTimeWithSingleDigits() {
        let result = TimeFormatter.formatTime(minutes: 5, seconds: 9)
        XCTAssertEqual(result, "05:09")
    }
    
    func testFormatTimeWithDoubleDigits() {
        let result = TimeFormatter.formatTime(minutes: 12, seconds: 34)
        XCTAssertEqual(result, "12:34")
    }
    
    func testFormatTimeWithZeros() {
        let result = TimeFormatter.formatTime(minutes: 0, seconds: 0)
        XCTAssertEqual(result, "00:00")
    }
    
    func testFormatTimeWithLargeValues() {
        let result = TimeFormatter.formatTime(minutes: 123, seconds: 45)
        XCTAssertEqual(result, "123:45")
    }
    
    // MARK: - formatSeconds Tests
    
    func testFormatSecondsLessThanOneMinute() {
        let result = TimeFormatter.formatSeconds(45)
        XCTAssertEqual(result, "00:45")
    }
    
    func testFormatSecondsExactlyOneMinute() {
        let result = TimeFormatter.formatSeconds(60)
        XCTAssertEqual(result, "01:00")
    }
    
    func testFormatSecondsMoreThanOneMinute() {
        let result = TimeFormatter.formatSeconds(90)
        XCTAssertEqual(result, "01:30")
    }
    
    func testFormatSecondsMultipleMinutes() {
        let result = TimeFormatter.formatSeconds(185)
        XCTAssertEqual(result, "03:05")
    }
    
    func testFormatSecondsZero() {
        let result = TimeFormatter.formatSeconds(0)
        XCTAssertEqual(result, "00:00")
    }
    
    func testFormatSecondsLargeValue() {
        let result = TimeFormatter.formatSeconds(3661)
        XCTAssertEqual(result, "61:01")
    }
}
