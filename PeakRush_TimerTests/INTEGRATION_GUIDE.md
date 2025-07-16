# PeakRush Timer - Test Integration Guide

This guide provides step-by-step instructions for integrating the PeakRush Timer test suite into your Xcode project.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Creating the Test Target](#creating-the-test-target)
- [Adding Test Files](#adding-test-files)
- [Configuring the Test Plan](#configuring-the-test-plan)
- [Setting Up Test Schemes](#setting-up-test-schemes)
- [Running the Tests](#running-the-tests)
- [Continuous Integration](#continuous-integration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before integrating the test suite, ensure you have:

- Xcode 14.0 or later
- The PeakRush Timer project open in Xcode
- Admin rights to modify the project

## Creating the Test Target

1. In Xcode, select your project in the Project Navigator
2. Click the "+" button at the bottom of the targets list
3. Select "New Target"
4. Choose "Unit Testing Bundle" under the iOS section
5. Name the target "PeakRush_TimerTests"
6. Ensure "Language" is set to "Swift"
7. Click "Finish"

## Adding Test Files

1. Create the directory structure in your project:

```
PeakRush_TimerTests/
├── Models/
├── ViewModels/
├── Services/
├── Utilities/
```

2. Add the test files to their respective directories:

   - **Models**: `TimerModelTests.swift`
   - **ViewModels**: `TimerConfigViewModelTests.swift`, `TimerRunViewModelTests.swift`
   - **Services**: `AudioManagerTests.swift`, `NotificationServiceTests.swift`
   - **Utilities**: `TimeFormatterTests.swift`
   - **Root**: `PeakRush_TimerTests.swift`, `README.md`, `INTEGRATION_GUIDE.md`, `TEST_COVERAGE.md`

3. For each file:
   - Right-click on the appropriate directory in the Project Navigator
   - Select "Add Files to 'PeakRush_Timer'..."
   - Navigate to the file location
   - Ensure "Add to targets" has "PeakRush_TimerTests" checked
   - Click "Add"

4. Add the shell script:
   - Add `run_tests.sh` to the root of the test directory
   - Make it executable with `chmod +x PeakRush_TimerTests/run_tests.sh`

## Configuring the Test Plan

1. Create a new Test Plan:
   - In Xcode, go to Product > Test Plan > New Test Plan...
   - Name it "PeakRush_Timer"
   - Save it in the `PeakRush_TimerTests` directory

2. Configure the Test Plan:
   - Select the newly created test plan
   - Click "Edit Test Plan" in the Test Navigator
   - Under "Tests", ensure "PeakRush_TimerTests" is selected
   - Under "Configurations", add a configuration named "Default"
   - Add another configuration named "With Code Coverage" and enable code coverage for it

3. Save the Test Plan:
   - Click "Done" to save the test plan
   - The test plan will be saved as `PeakRush_Timer.xctestplan`

## Setting Up Test Schemes

1. Edit the Scheme:
   - Go to Product > Scheme > Edit Scheme...
   - Select "Test" in the left sidebar
   - Under "Test Plans", click "+" and select your test plan
   - Make sure it's checked
   - Click "Close"

2. Create a Dedicated Test Scheme (Optional):
   - Go to Product > Scheme > New Scheme...
   - Name it "PeakRush_TimerTests"
   - Select "PeakRush_TimerTests" as the target
   - Click "OK"
   - Edit this scheme and set the test plan as above

## Running the Tests

### Using Xcode

1. Select the appropriate scheme (either your main scheme or the dedicated test scheme)
2. Go to Product > Test or press Cmd+U
3. View the test results in the Test Navigator

### Using Command Line

1. Make sure the `run_tests.sh` script is executable:
   ```bash
   chmod +x PeakRush_TimerTests/run_tests.sh
   ```

2. Run the tests:
   ```bash
   ./PeakRush_TimerTests/run_tests.sh
   ```

3. For more options:
   ```bash
   ./PeakRush_TimerTests/run_tests.sh --help
   ```

## Continuous Integration

### GitHub Actions

To set up GitHub Actions for running tests:

1. Create a `.github/workflows` directory in your project
2. Create a file named `tests.yml` with the following content:

```yaml
name: Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    - name: Build and Test
      run: |
        xcodebuild test -project PeakRush_Timer.xcodeproj -scheme PeakRush_TimerTests -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.0'
```

### Jenkins

For Jenkins integration:

1. Install the Xcode Integration plugin
2. Create a new Jenkins job
3. Configure the job to run the following command:

```bash
xcodebuild test -project PeakRush_Timer.xcodeproj -scheme PeakRush_TimerTests -destination 'platform=iOS Simulator,name=iPhone 14,OS=16.0'
```

## Troubleshooting

### Common Issues

1. **Test Target Not Found**:
   - Ensure the test target is properly created and configured
   - Check that the target membership for test files is correct

2. **Import Errors**:
   - Ensure the test target has access to the main target
   - Add `@testable import PeakRush_Timer` to the test files

3. **Test Files Not Found**:
   - Check that the files are added to the correct target
   - Verify the file paths are correct

4. **Test Plan Not Found**:
   - Ensure the test plan is saved in the correct location
   - Check that the test plan is added to the scheme

5. **Command Line Tests Fail**:
   - Ensure the `run_tests.sh` script is executable
   - Check that the project path and scheme name are correct in the script

### Getting Help

If you encounter issues integrating the tests:

1. Check the Xcode console for error messages
2. Review the test files for any import or configuration issues
3. Ensure all dependencies are properly set up
4. Check the Xcode project settings for any conflicts

For more help, refer to the [Apple Developer Documentation on Testing](https://developer.apple.com/documentation/xcode/testing-your-apps-in-xcode).
