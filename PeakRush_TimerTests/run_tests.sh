#!/bin/bash

# Script to run PeakRush Timer tests from the command line

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}   PeakRush Timer - Test Runner       ${NC}"
echo -e "${BLUE}=======================================${NC}"

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild command not found.${NC}"
    echo -e "${YELLOW}Please make sure Xcode is installed and the command line tools are set up.${NC}"
    exit 1
fi

# Default values
PROJECT_PATH="$(dirname "$0")/.."
PROJECT_NAME="PeakRush_Timer.xcodeproj"
TEST_SCHEME="PeakRush_TimerTests"
DESTINATION="platform=iOS Simulator,name=iPhone 15,OS=17.0"
CODE_COVERAGE=false
VERBOSE=false
TEST_CLASS=""
TEST_METHOD=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--project)
            PROJECT_PATH="$2"
            shift
            shift
            ;;
        -s|--scheme)
            TEST_SCHEME="$2"
            shift
            shift
            ;;
        -d|--destination)
            DESTINATION="$2"
            shift
            shift
            ;;
        -c|--coverage)
            CODE_COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -t|--test-class)
            TEST_CLASS="$2"
            shift
            shift
            ;;
        -m|--test-method)
            TEST_METHOD="$2"
            shift
            shift
            ;;
        -h|--help)
            echo -e "${BLUE}Usage:${NC}"
            echo -e "  $0 [options]"
            echo -e ""
            echo -e "${BLUE}Options:${NC}"
            echo -e "  -p, --project PATH      Path to the project directory (default: parent directory)"
            echo -e "  -s, --scheme SCHEME     Test scheme to run (default: PeakRush_TimerTests)"
            echo -e "  -d, --destination DEST  Test destination (default: iPhone 15 simulator)"
            echo -e "  -c, --coverage          Enable code coverage reporting"
            echo -e "  -v, --verbose           Enable verbose output"
            echo -e "  -t, --test-class CLASS  Run only tests in the specified class"
            echo -e "  -m, --test-method METHOD Run only the specified test method (requires -t)"
            echo -e "  -h, --help              Show this help message"
            echo -e ""
            echo -e "${BLUE}Examples:${NC}"
            echo -e "  $0 -c                   Run all tests with code coverage"
            echo -e "  $0 -t TimerModelTests   Run only TimerModelTests"
            echo -e "  $0 -t TimerModelTests -m testTotalSeconds  Run only the testTotalSeconds method"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $key${NC}"
            echo -e "${YELLOW}Use --help to see available options${NC}"
            exit 1
            ;;
    esac
done

# Build the command
CMD="xcodebuild test -project \"$PROJECT_PATH/$PROJECT_NAME\" -scheme \"$TEST_SCHEME\" -destination \"$DESTINATION\""

# Add code coverage if requested
if [ "$CODE_COVERAGE" = true ]; then
    CMD="$CMD -enableCodeCoverage YES"
    echo -e "${BLUE}Code coverage enabled${NC}"
fi

# Add test class and method if specified
if [ ! -z "$TEST_CLASS" ]; then
    if [ ! -z "$TEST_METHOD" ]; then
        CMD="$CMD -only-testing:$TEST_SCHEME/$TEST_CLASS/$TEST_METHOD"
        echo -e "${BLUE}Running test: $TEST_CLASS.$TEST_METHOD${NC}"
    else
        CMD="$CMD -only-testing:$TEST_SCHEME/$TEST_CLASS"
        echo -e "${BLUE}Running test class: $TEST_CLASS${NC}"
    fi
else
    echo -e "${BLUE}Running all tests${NC}"
fi

# Add formatting based on verbose flag
if [ "$VERBOSE" = false ]; then
    CMD="$CMD | xcpretty"
fi

# Print the command if verbose
if [ "$VERBOSE" = true ]; then
    echo -e "${YELLOW}Executing: $CMD${NC}"
fi

# Run the command
echo -e "${BLUE}Starting tests...${NC}"
echo -e "${BLUE}=======================================${NC}"

# Execute the command
if [ "$VERBOSE" = true ]; then
    eval "$CMD"
else
    eval "$CMD | xcpretty"
fi

# Check the result
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Tests completed successfully!${NC}"
    exit 0
else
    echo -e "${RED}Tests failed.${NC}"
    exit 1
fi
