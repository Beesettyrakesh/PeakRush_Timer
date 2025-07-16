# PeakRush Timer - Unit Test Suite

This directory contains a comprehensive unit testing suite for the PeakRush Timer iOS application. The tests are designed to verify the functionality of the app's components, including models, view models, services, and utilities.

## Table of Contents

- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Test Files](#test-files)
- [Mocking Strategy](#mocking-strategy)
- [Adding New Tests](#adding-new-tests)
- [Test Coverage](#test-coverage)
- [Troubleshooting](#troubleshooting)

## Test Structure

The test suite follows a structured approach to testing the various components of the PeakRush Timer app:

```
PeakRush_TimerTests/
├── Models/
│   └── TimerModelTests.swift
├── ViewModels/
│   ├── TimerConfigViewModelTests.swift
│   └── TimerRunViewModelTests.swift
├── Services/
│   ├── AudioManagerTests.swift
│   └── NotificationServiceTests.swift
├── Utilities/
│   └── TimeFormatterTests.swift
├── PeakRush_TimerTests.swift
├── PeakRush_Timer.xctestplan
├── README.md
├── INTEGRATION_GUIDE.md
├── TEST_COVERAGE.md
└── run_tests.sh
```

Each test file focuses on a specific component of the application, with tests organized by functionality.

## Running Tests

### Using Xcode

1. Open the PeakRush_Timer project in Xcode
2. Select the PeakRush_TimerTests scheme
3. Press `Cmd+U` or select `Product > Test`

### Using Command Line

The included `run_tests.sh` script provides a convenient way to run tests from the command line:

```bash
# Run all tests
./PeakRush_TimerTests/run_tests.sh

# Run with code coverage
./PeakRush_TimerTests/run_tests.sh --coverage

# Run a specific test class
./PeakRush_TimerTests/run_tests.sh --test-class TimerModelTests

# Run a specific test method
./PeakRush_TimerTests/run_tests.sh --test-class TimerModelTests --test-method testTotalSeconds

# Show help
./PeakRush_TimerTests/run_tests.sh --help
```

## Test Files

### PeakRush_TimerTests.swift

The main test file that serves as the entry point for the test suite. It contains basic tests for app initialization and provides documentation about the test suite structure.

### Models

- **TimerModelTests.swift**: Tests for the `TimerModel` class, including initialization, computed properties, configuration validation, and runtime state.

### ViewModels

- **TimerConfigViewModelTests.swift**: Tests for the `TimerConfigViewModel` class, including bindings, computed properties, and factory methods.
- **TimerRunViewModelTests.swift**: Tests for the `TimerRunViewModel` class, including UI properties, timer control, timer updates, audio integration, and background processing.

### Services

- **AudioManagerTests.swift**: Tests for the `AudioManager` class, including audio session configuration, sound playback, speech synthesis, and interruption handling.
- **NotificationServiceTests.swift**: Tests for the `NotificationService` class, including permission handling, notification scheduling, and notification cancellation.

### Utilities

- **TimeFormatterTests.swift**: Tests for the `TimeFormatter` utility, including time formatting methods.

## Mocking Strategy

The test suite uses several approaches to mock dependencies:

1. **Simple Mocks**: For straightforward dependencies, we create simple mock classes that implement the same interface as the real class but with controlled behavior.

2. **Protocol-Based Mocks**: For services with well-defined interfaces, we create mock implementations of the protocols.

3. **Subclass Mocks**: For system classes like `AVAudioPlayer` and `UNUserNotificationCenter`, we create subclasses that override the methods we need to test.

4. **Method Swizzling**: For static methods and singletons, we use method swizzling to replace the implementation with our mock implementation during tests.

5. **Reflection**: For accessing and modifying private properties, we use reflection to inject our mocks into the classes under test.

## Adding New Tests

### Creating a New Test File

1. Create a new file in the appropriate directory (Models, ViewModels, Services, or Utilities)
2. Import the necessary modules:

```swift
import XCTest
@testable import PeakRush_Timer
```

3. Create a test class that inherits from `XCTestCase`:

```swift
class YourComponentTests: XCTestCase {
    
    // Setup and teardown
    override func setUp() {
        super.setUp()
        // Initialize your component and any dependencies
    }
    
    override func tearDown() {
        // Clean up resources
        super.tearDown()
    }
    
    // Test methods
    func testYourFeature() {
        // Given
        // Set up the initial state
        
        // When
        // Perform the action being tested
        
        // Then
        // Verify the expected outcome using XCTAssert methods
    }
}
```

### Test Naming Conventions

- Test methods should start with `test`
- Test names should clearly describe what is being tested
- Use the Given-When-Then pattern in test methods to make them more readable

### Mocking Dependencies

When testing a component that has dependencies, create mock implementations of those dependencies:

```swift
class MockDependency {
    var methodCalled = false
    var returnValue: Any?
    
    func method() -> Any? {
        methodCalled = true
        return returnValue
    }
}
```

Then inject the mock into the component under test:

```swift
// Create the mock
let mockDependency = MockDependency()
mockDependency.returnValue = "test"

// Inject the mock into the component
component.dependency = mockDependency

// Test the component
component.methodThatUsesDependency()

// Verify the mock was used correctly
XCTAssertTrue(mockDependency.methodCalled)
```

## Test Coverage

See `TEST_COVERAGE.md` for a detailed analysis of test coverage and recommendations for improvement.

The current test suite provides good coverage of the app's functionality, but there are areas that could be improved:

1. **TimerRunViewModel**: More tests for background processing and timer firing compensation
2. **AudioManager**: More tests for interruption handling and audio session management
3. **NotificationService**: More tests for dynamic buffer calculation

## Troubleshooting

### Common Issues

1. **Tests Fail to Build**: Ensure that the test target is correctly configured and that all necessary files are included in the test target.

2. **Tests Fail Due to Missing Dependencies**: Make sure all dependencies are properly mocked or injected.

3. **Tests Fail Due to Asynchronous Operations**: Use `XCTestExpectation` to wait for asynchronous operations to complete:

```swift
let expectation = XCTestExpectation(description: "Async operation completes")

// Perform async operation
someAsyncOperation {
    // Verify results
    expectation.fulfill()
}

wait(for: [expectation], timeout: 5.0)
```

4. **Tests Fail Due to UI Updates**: UI updates must be performed on the main thread. Use `DispatchQueue.main.async` to ensure UI updates happen on the main thread.

### Getting Help

If you encounter issues with the test suite, please:

1. Check the Xcode console for error messages
2. Review the test file for the failing test
3. Ensure all dependencies are properly mocked
4. Check for any recent changes to the component being tested

## License

This test suite is part of the PeakRush Timer application and is subject to the same license terms.
