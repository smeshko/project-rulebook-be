#!/bin/bash

# =============================================================================
# Complete Test Suite Runner for Project Rulebook
# =============================================================================
# Purpose: Runs all tests (unit, integration, endpoint) with comprehensive reporting
# Author: Project Rulebook Team
# Version: 1.0.0
# Last Updated: 2025-08-13
# =============================================================================
#
# USAGE:
#   ./run-all-tests.sh [options]
#
# OPTIONS:
#   -h, --help          Show this help message
#   -u, --unit-only     Run only unit tests
#   -e, --endpoint-only Run only endpoint tests
#   -s, --skip-server   Don't start server for endpoint tests
#   -c, --coverage      Generate code coverage report
#   -v, --verbose       Show detailed output
#   -q, --quiet         Minimize output
#
# EXAMPLES:
#   ./run-all-tests.sh              # Run all tests
#   ./run-all-tests.sh -u           # Unit tests only
#   ./run-all-tests.sh -c           # Run with coverage
#   ./run-all-tests.sh -v           # Verbose output
#
# =============================================================================

set -e

# Script directory detection
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"
TESTING_DIR="$SCRIPT_DIR/.."
REPORTS_DIR="$TESTING_DIR/reports"

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default configuration
RUN_UNIT=true
RUN_ENDPOINT=true
SKIP_SERVER=false
COVERAGE=false
VERBOSE=false
QUIET=false

# Test results
UNIT_PASSED=false
ENDPOINT_PASSED=false
TOTAL_START_TIME=$(date +%s)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            grep "^#" "$0" | grep -E "(USAGE|OPTIONS|EXAMPLES):" -A 20 | grep -v "grep" | cut -c3-
            exit 0
            ;;
        -u|--unit-only)
            RUN_UNIT=true
            RUN_ENDPOINT=false
            shift
            ;;
        -e|--endpoint-only)
            RUN_UNIT=false
            RUN_ENDPOINT=true
            shift
            ;;
        -s|--skip-server)
            SKIP_SERVER=true
            shift
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Function to print colored messages
print_message() {
    local type=$1
    local message=$2
    
    if [[ "$QUIET" == true ]] && [[ "$type" == "INFO" ]]; then
        return
    fi
    
    case $type in
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        "HEADER")
            echo -e "${MAGENTA}$message${NC}"
            ;;
        "SECTION")
            echo -e "${CYAN}$message${NC}"
            ;;
    esac
}

# Function to calculate elapsed time
calculate_elapsed() {
    local start_time=$1
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    echo "${minutes}m ${seconds}s"
}

# Function to run unit tests
run_unit_tests() {
    print_message "SECTION" "═══════════════════════════════════════════════════════════════"
    print_message "SECTION" "                    RUNNING UNIT TESTS                         "
    print_message "SECTION" "═══════════════════════════════════════════════════════════════"
    
    local start_time=$(date +%s)
    
    cd "$PROJECT_ROOT"
    
    # Build command based on options
    local test_cmd="swift test"
    
    if [[ "$COVERAGE" == true ]]; then
        test_cmd="$test_cmd --enable-code-coverage"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        test_cmd="$test_cmd --verbose"
    elif [[ "$QUIET" == true ]]; then
        test_cmd="$test_cmd 2>&1 | grep -E '(Test Suite|passed|failed|error)' || true"
    fi
    
    # Run tests and capture result
    if eval "$test_cmd"; then
        UNIT_PASSED=true
        print_message "SUCCESS" "✅ All unit tests passed"
        
        # Generate coverage report if requested
        if [[ "$COVERAGE" == true ]]; then
            print_message "INFO" "Generating coverage report..."
            
            # Find the binary path
            local binary_path=$(swift build --show-bin-path)
            local coverage_file="$binary_path/../debug.json"
            
            if [[ -f "$coverage_file" ]]; then
                # Export coverage data (simplified version)
                swift test --enable-code-coverage --show-codecov-path > "$REPORTS_DIR/coverage-path.txt" 2>&1
                print_message "SUCCESS" "Coverage data saved to reports directory"
            fi
        fi
    else
        UNIT_PASSED=false
        print_message "ERROR" "❌ Unit tests failed"
    fi
    
    local elapsed=$(calculate_elapsed $start_time)
    print_message "INFO" "Unit tests completed in $elapsed"
    echo
}

# Function to run endpoint tests
run_endpoint_tests() {
    print_message "SECTION" "═══════════════════════════════════════════════════════════════"
    print_message "SECTION" "                   RUNNING ENDPOINT TESTS                      "
    print_message "SECTION" "═══════════════════════════════════════════════════════════════"
    
    local start_time=$(date +%s)
    
    cd "$PROJECT_ROOT"
    
    # Build command based on options
    local test_cmd="$SCRIPT_DIR/test-endpoints.sh"
    
    if [[ "$SKIP_SERVER" == true ]]; then
        test_cmd="$test_cmd --skip-server"
    fi
    
    if [[ "$VERBOSE" == true ]]; then
        test_cmd="$test_cmd --verbose"
    elif [[ "$QUIET" == true ]]; then
        test_cmd="$test_cmd --quiet"
    fi
    
    # Run endpoint tests
    if $test_cmd; then
        ENDPOINT_PASSED=true
        print_message "SUCCESS" "✅ All endpoint tests passed"
    else
        ENDPOINT_PASSED=false
        print_message "ERROR" "❌ Endpoint tests failed"
    fi
    
    local elapsed=$(calculate_elapsed $start_time)
    print_message "INFO" "Endpoint tests completed in $elapsed"
    echo
}

# Function to generate summary report
generate_summary() {
    local total_elapsed=$(calculate_elapsed $TOTAL_START_TIME)
    
    print_message "HEADER" "═══════════════════════════════════════════════════════════════"
    print_message "HEADER" "                      TEST SUMMARY REPORT                      "
    print_message "HEADER" "═══════════════════════════════════════════════════════════════"
    
    echo
    echo "Test Results:"
    echo "────────────────────────────────────"
    
    if [[ "$RUN_UNIT" == true ]]; then
        if [[ "$UNIT_PASSED" == true ]]; then
            echo -e "  Unit Tests:     ${GREEN}✅ PASSED${NC}"
        else
            echo -e "  Unit Tests:     ${RED}❌ FAILED${NC}"
        fi
    fi
    
    if [[ "$RUN_ENDPOINT" == true ]]; then
        if [[ "$ENDPOINT_PASSED" == true ]]; then
            echo -e "  Endpoint Tests: ${GREEN}✅ PASSED${NC}"
        else
            echo -e "  Endpoint Tests: ${RED}❌ FAILED${NC}"
        fi
    fi
    
    echo
    echo "Configuration:"
    echo "────────────────────────────────────"
    echo "  Coverage:       $([ "$COVERAGE" == true ] && echo "Enabled" || echo "Disabled")"
    echo "  Verbose:        $([ "$VERBOSE" == true ] && echo "Yes" || echo "No")"
    echo "  Total Time:     $total_elapsed"
    
    echo
    echo "Reports Location:"
    echo "────────────────────────────────────"
    echo "  Logs:           $TESTING_DIR/logs/"
    echo "  Reports:        $TESTING_DIR/reports/"
    
    # Determine overall result
    local overall_passed=true
    
    if [[ "$RUN_UNIT" == true ]] && [[ "$UNIT_PASSED" == false ]]; then
        overall_passed=false
    fi
    
    if [[ "$RUN_ENDPOINT" == true ]] && [[ "$ENDPOINT_PASSED" == false ]]; then
        overall_passed=false
    fi
    
    echo
    if [[ "$overall_passed" == true ]]; then
        print_message "SUCCESS" "🎉 ALL TESTS PASSED! 🎉"
        return 0
    else
        print_message "ERROR" "❌ SOME TESTS FAILED - Please review the logs"
        return 1
    fi
}

# Main execution
main() {
    print_message "HEADER" "═══════════════════════════════════════════════════════════════"
    print_message "HEADER" "           PROJECT RULEBOOK - COMPLETE TEST SUITE              "
    print_message "HEADER" "═══════════════════════════════════════════════════════════════"
    
    # Record start time and date
    print_message "INFO" "Started at: $(date '+%Y-%m-%d %H:%M:%S')"
    print_message "INFO" "Project Root: $PROJECT_ROOT"
    echo
    
    # Run unit tests if requested
    if [[ "$RUN_UNIT" == true ]]; then
        run_unit_tests
    fi
    
    # Run endpoint tests if requested
    if [[ "$RUN_ENDPOINT" == true ]]; then
        run_endpoint_tests
    fi
    
    # Generate summary report
    generate_summary
}

# Run main function and exit with appropriate code
main "$@"
exit_code=$?
exit $exit_code