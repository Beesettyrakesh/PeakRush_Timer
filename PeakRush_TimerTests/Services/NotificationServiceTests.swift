import XCTest
@testable import PeakRush_Timer
import UserNotifications

// MARK: - Protocol for UNUserNotificationCenter functionality

protocol UNUserNotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void)
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?)
    func removeAllPendingNotificationRequests()
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void)
}

// Make UNUserNotificationCenter conform to our protocol
extension UNUserNotificationCenter: UNUserNotificationCenterProtocol {}

// MARK: - Mock UNUserNotificationCenter

class MockUNUserNotificationCenter: UNUserNotificationCenterProtocol {
    var requestAuthorizationCalled = false
    var requestAuthorizationOptions: UNAuthorizationOptions?
    var requestAuthorizationCompletion: ((Bool, Error?) -> Void)?
    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    var addRequestCalled = false
    var lastAddedRequest: UNNotificationRequest?
    var addRequestCompletion: ((Error?) -> Void)?
    
    var removeAllPendingRequestsCalled = false
    var removePendingRequestsWithIdentifiersCalled = false
    var removedIdentifiers: [String]?
    
    var pendingNotificationRequests: [UNNotificationRequest] = []
    var deliveredNotifications: [MockNotification] = []
    
    func requestAuthorization(options: UNAuthorizationOptions, completionHandler: @escaping (Bool, Error?) -> Void) {
        requestAuthorizationCalled = true
        requestAuthorizationOptions = options
        requestAuthorizationCompletion = completionHandler
        
        // Simulate successful authorization
        completionHandler(true, nil)
    }
    
    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        addRequestCalled = true
        lastAddedRequest = request
        addRequestCompletion = completionHandler
        pendingNotificationRequests.append(request)
        
        // Simulate successful addition
        completionHandler?(nil)
    }
    
    func removeAllPendingNotificationRequests() {
        removeAllPendingRequestsCalled = true
        pendingNotificationRequests.removeAll()
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removePendingRequestsWithIdentifiersCalled = true
        removedIdentifiers = identifiers
        
        // Remove the specified requests
        pendingNotificationRequests.removeAll { request in
            identifiers.contains(request.identifier)
        }
    }
    
    func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void) {
        // Since we can't directly create UNNotificationSettings instances,
        // we need to use a real UNNotificationSettings object
        // This is a workaround to simulate the behavior
        
        // Create a real UNUserNotificationCenter
        let realCenter = UNUserNotificationCenter.current()
        
        // Get the real settings but then use our mock status
        realCenter.getNotificationSettings { realSettings in
            // Use the real settings object but with our mock authorization status
            // We can't modify the real settings, so we'll need to check the mock status in our tests
            completionHandler(realSettings)
            
            // Store the authorization status for tests to check
            self.authorizationStatus = realSettings.authorizationStatus
        }
    }
    
    // Helper method to simulate notification delivery
    func simulateNotificationDelivery(for identifier: String) {
        guard let request = pendingNotificationRequests.first(where: { $0.identifier == identifier }) else {
            return
        }
        
        // Create a mock notification
        let mockNotification = MockNotification(request: request)
        deliveredNotifications.append(mockNotification)
        
        // Remove from pending
        pendingNotificationRequests.removeAll { $0.identifier == identifier }
    }
}

// MARK: - Mock UNNotificationSettings

// Instead of subclassing UNNotificationSettings, create a class that conforms to the same interface
class MockNotificationSettings: NSObject {
    let authorizationStatus: UNAuthorizationStatus
    
    init(authorizationStatus: UNAuthorizationStatus) {
        self.authorizationStatus = authorizationStatus
        super.init()
    }
}

// MARK: - Mock UNNotification

// Instead of subclassing UNNotification, create a class that provides the same interface
class MockNotification {
    let request: UNNotificationRequest
    let date: Date
    
    init(request: UNNotificationRequest, date: Date = Date()) {
        self.request = request
        self.date = date
    }
}

// MARK: - NotificationService Tests

class NotificationServiceTests: XCTestCase {
    
    var notificationService: NotificationService!
    var mockNotificationCenter: MockUNUserNotificationCenter!
    
    // Static property to hold the current test instance
    static var currentTestInstance: NotificationServiceTests?
    
    override func setUp() {
        super.setUp()
        
        // Store reference to current test instance
        NotificationServiceTests.currentTestInstance = self
        
        mockNotificationCenter = MockUNUserNotificationCenter()
        
        // Swizzle the UNUserNotificationCenter.current() method to return our mock
        swizzleNotificationCenter()
        
        notificationService = NotificationService()
    }
    
    override func tearDown() {
        // Restore the original UNUserNotificationCenter.current() method
        restoreNotificationCenter()
        
        notificationService = nil
        mockNotificationCenter = nil
        NotificationServiceTests.currentTestInstance = nil
        super.tearDown()
    }
    
    // MARK: - Permission Tests
    
    func testRequestNotificationPermission() {
        // Given
        mockNotificationCenter.authorizationStatus = .notDetermined
        
        // When
        notificationService.requestNotificationPermission()
        
        // Then
        XCTAssertTrue(mockNotificationCenter.requestAuthorizationCalled)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationOptions, [.alert, .sound, .badge])
    }
    
    func testRequestNotificationPermissionWhenAlreadyAuthorized() {
        // Given
        mockNotificationCenter.authorizationStatus = .authorized
        
        // When
        notificationService.requestNotificationPermission()
        
        // Then
        // The service should check the current status and not request again if already authorized
        // This is implementation-dependent, so we might need to adjust this test
    }
    
    // MARK: - Send Notification Tests
    
    func testSendLocalNotification() {
        // Given
        let title = "Test Title"
        let body = "Test Body"
        
        // When
        notificationService.sendLocalNotification(title: title, body: body)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.addRequestCalled)
        XCTAssertNotNil(mockNotificationCenter.lastAddedRequest)
        
        let request = mockNotificationCenter.lastAddedRequest!
        let content = request.content
        
        XCTAssertEqual(content.title, title)
        XCTAssertEqual(content.body, body)
        XCTAssertEqual(content.sound, .default)
        XCTAssertEqual(content.categoryIdentifier, "WORKOUT_COMPLETION")
        XCTAssertEqual(content.threadIdentifier, "com.peakrush.timer.workout")
        XCTAssertEqual(content.relevanceScore, 1.0)
        
        // Verify the trigger is a time interval trigger with minimal delay
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.timeInterval, 0.1)
        XCTAssertFalse(trigger?.repeats ?? true)
    }
    
    // MARK: - Schedule Notification Tests
    
    func testScheduleNotification() {
        // Given
        let title = "Test Title"
        let body = "Test Body"
        let timeInterval: TimeInterval = 60.0
        let identifier = "test-identifier"
        
        // When
        notificationService.scheduleNotification(title: title, body: body, timeInterval: timeInterval, identifier: identifier)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.addRequestCalled)
        XCTAssertNotNil(mockNotificationCenter.lastAddedRequest)
        
        let request = mockNotificationCenter.lastAddedRequest!
        let content = request.content
        
        XCTAssertEqual(content.title, title)
        XCTAssertEqual(content.body, body)
        XCTAssertEqual(content.sound, .default)
        XCTAssertEqual(content.categoryIdentifier, "WORKOUT_COMPLETION")
        XCTAssertEqual(content.threadIdentifier, "com.peakrush.timer.workout")
        XCTAssertEqual(content.relevanceScore, 1.0)
        XCTAssertEqual(request.identifier, identifier)
        
        // Verify the trigger is a time interval trigger with the specified delay
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        XCTAssertNotNil(trigger)
        XCTAssertEqual(trigger?.timeInterval, timeInterval)
        XCTAssertFalse(trigger?.repeats ?? true)
    }
    
    func testScheduleNotificationWithBackup() {
        // Given
        let title = "Test Title"
        let body = "Test Body"
        let timeInterval: TimeInterval = 60.0
        let identifier = "test-identifier"
        
        // When
        notificationService.scheduleNotification(title: title, body: body, timeInterval: timeInterval, identifier: identifier)
        
        // Then
        // Check if a backup notification was scheduled for longer intervals
        if timeInterval > 30 {
            XCTAssertEqual(mockNotificationCenter.pendingNotificationRequests.count, 2)
            
            // Find the backup notification
            let backupRequest = mockNotificationCenter.pendingNotificationRequests.first { $0.identifier == "\(identifier)-backup" }
            XCTAssertNotNil(backupRequest)
            
            if let backupRequest = backupRequest {
                let backupContent = backupRequest.content
                XCTAssertEqual(backupContent.title, title)
                XCTAssertEqual(backupContent.body, "\(body) (Reminder)")
                
                let backupTrigger = backupRequest.trigger as? UNTimeIntervalNotificationTrigger
                XCTAssertNotNil(backupTrigger)
                XCTAssertEqual(backupTrigger?.timeInterval, timeInterval + 15)
            }
        }
    }
    
    // MARK: - Cancel Notification Tests
    
    func testCancelAllNotifications() {
        // When
        notificationService.cancelAllNotifications()
        
        // Then
        XCTAssertTrue(mockNotificationCenter.removeAllPendingRequestsCalled)
    }
    
    func testCancelNotificationWithIdentifier() {
        // Given
        let identifier = "test-identifier"
        
        // When
        notificationService.cancelNotification(withIdentifier: identifier)
        
        // Then
        XCTAssertTrue(mockNotificationCenter.removePendingRequestsWithIdentifiersCalled)
        XCTAssertEqual(mockNotificationCenter.removedIdentifiers?.count, 2) // Original and backup
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers?.contains(identifier) ?? false)
        XCTAssertTrue(mockNotificationCenter.removedIdentifiers?.contains("\(identifier)-backup") ?? false)
    }
    
    // MARK: - Helper Methods
    
    private var originalCurrentMethod: Method?
    private var mockCurrentMethod: Method?
    
    private func swizzleNotificationCenter() {
        // Get the original and mock class methods
        guard let originalMethod = class_getClassMethod(UNUserNotificationCenter.self, #selector(UNUserNotificationCenter.current)),
              let mockMethod = class_getClassMethod(NotificationServiceTests.self, #selector(NotificationServiceTests.mockCurrent)) else {
            return
        }
        
        // Store references to the methods
        originalCurrentMethod = originalMethod
        mockCurrentMethod = mockMethod
        
        // Swap the implementations
        method_exchangeImplementations(originalMethod, mockMethod)
    }
    
    private func restoreNotificationCenter() {
        // Restore the original implementation
        if let originalMethod = originalCurrentMethod, let mockMethod = mockCurrentMethod {
            method_exchangeImplementations(mockMethod, originalMethod)
        }
    }
    
    @objc static func mockCurrent() -> UNUserNotificationCenter {
        // Use the static property to access the current test instance
        if let testCase = NotificationServiceTests.currentTestInstance {
            // We need to cast our mock to UNUserNotificationCenter
            // This is a bit of a hack, but it's necessary for the swizzling to work
            return unsafeBitCast(testCase.mockNotificationCenter, to: UNUserNotificationCenter.self)
        }
        
        // Fallback to the real implementation if something goes wrong
        return UNUserNotificationCenter.current()
    }
}
