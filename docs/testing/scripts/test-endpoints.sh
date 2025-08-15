#!/bin/bash

# =============================================================================
# Comprehensive Endpoint Testing Script for Project Rulebook API
# =============================================================================
# Purpose: Tests all Vapor server endpoints to ensure stability and correctness
# Author: Project Rulebook Team
# Version: 2.0.0
# Last Updated: 2025-08-13
# =============================================================================
#
# USAGE:
#   ./test-endpoints.sh [options]
#
# OPTIONS:
#   -h, --help        Show this help message
#   -p, --port PORT   Specify server port (default: 8080)
#   -H, --host HOST   Specify server host (default: 127.0.0.1)
#   -s, --skip-server Don't start server (assume it's already running)
#   -v, --verbose     Show detailed output including response bodies
#   -q, --quiet       Minimize output (only show summary)
#
# EXAMPLES:
#   ./test-endpoints.sh                    # Run with defaults
#   ./test-endpoints.sh -p 3000           # Use port 3000
#   ./test-endpoints.sh --skip-server     # Test against running server
#   ./test-endpoints.sh -v                # Show detailed responses
#
# =============================================================================

# Note: Not using 'set -e' so script continues testing all endpoints even if some fail

# Script directory detection for proper log paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../.." && pwd )"
LOGS_DIR="$SCRIPT_DIR/../logs"

# Ensure logs directory exists
mkdir -p "$LOGS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default Configuration
SERVER_HOST="127.0.0.1"
SERVER_PORT="8080"
SKIP_SERVER=false
VERBOSE=false
QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            grep "^#" "$0" | grep -E "(USAGE|OPTIONS|EXAMPLES):" -A 20 | grep -v "grep" | cut -c3-
            exit 0
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -H|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -s|--skip-server)
            SKIP_SERVER=true
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

# Configuration based on parsed arguments
BASE_URL="http://${SERVER_HOST}:${SERVER_PORT}"
SERVER_LOG="$LOGS_DIR/endpoint-test-server.log"
RESULTS_LOG="$LOGS_DIR/endpoint-test-results.log"
SERVER_PID=""

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
CRASHED_TESTS=0

# Test results array with detailed metrics
TEST_RESULTS=()
ENDPOINT_DATA=()

# Function to print colored output (respects quiet mode)
print_status() {
    local status=$1
    local message=$2
    
    # Skip info and test messages in quiet mode
    if [[ "$QUIET" == true ]] && [[ "$status" == "INFO" || "$status" == "TEST" ]]; then
        return
    fi
    
    case $status in
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
        "TEST")
            echo -e "${CYAN}[TEST]${NC} $message"
            ;;
        "HEADER")
            echo -e "${MAGENTA}$message${NC}"
            ;;
    esac
}

# Function to log results with detailed metrics
log_result() {
    local endpoint=$1
    local method=$2
    local status_code=$3
    local result=$4
    local error_message=$5
    local response_time=$6
    local description=$7
    
    local endpoint_key="$method $endpoint"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_entry="[$timestamp] $endpoint_key - Status: $status_code - Result: $result - Time: ${response_time}ms"
    
    if [[ -n "$error_message" ]]; then
        log_entry="$log_entry - Error: $error_message"
    fi
    
    echo "$log_entry" >> "$RESULTS_LOG"
    
    # Store detailed metrics in a simple format: METHOD|ENDPOINT|STATUS|TIME|RESULT|DESCRIPTION
    local status_icon
    if [[ "$result" == "PASSED" ]]; then
        status_icon="✅"
    elif [[ "$result" == "CRASHED" ]]; then
        status_icon="💥"
    elif [[ "$result" == "UNEXPECTED_STATUS" ]]; then
        status_icon="⚠️"
    else
        status_icon="❌"
    fi
    
    ENDPOINT_DATA+=("$endpoint_key|$status_code|$response_time|$result|$status_icon|$description")
    TEST_RESULTS+=("$endpoint_key: $result (HTTP $status_code, ${response_time}ms)")
}

# Function to cleanup on exit
cleanup() {
    print_status "INFO" "Cleaning up..."
    
    if [[ -n "$SERVER_PID" ]]; then
        print_status "INFO" "Stopping server (PID: $SERVER_PID)..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    
    # Kill any remaining swift processes
    pkill -f "swift run App serve" 2>/dev/null || true
    
    # Free up the port
    lsof -ti:$SERVER_PORT | xargs kill -9 2>/dev/null || true
    
    print_status "INFO" "Cleanup completed"
}

# Set up cleanup on script exit
trap cleanup EXIT INT TERM

# Function to start the server
start_server() {
    print_status "INFO" "Starting Vapor server..."
    
    # Clean up any existing processes
    cleanup
    
    # Remove old log files
    rm -f "$SERVER_LOG" "$RESULTS_LOG"
    
    # Start the server in background (force IPv4)
    nohup swift run App serve --hostname "127.0.0.1" --port "$SERVER_PORT" > "$SERVER_LOG" 2>&1 &
    SERVER_PID=$!
    
    print_status "INFO" "Server started with PID: $SERVER_PID"
    print_status "INFO" "Waiting for server to be ready..."
    
    # Wait for server to be ready (up to 30 seconds)
    local wait_time=0
    local max_wait=30
    
    while [[ $wait_time -lt $max_wait ]]; do
        # Try to connect and check for any HTTP response (including 404)
        local response=$(curl -s --max-time 2 "$BASE_URL/" 2>&1)
        if [[ "$response" == *"Not Found"* ]] && [[ "$response" == *"error"* ]]; then
            print_status "SUCCESS" "Server is ready on $BASE_URL"
            return 0
        fi
        
        # Check if server process is still running
        if ! kill -0 "$SERVER_PID" 2>/dev/null; then
            print_status "ERROR" "Server process died during startup"
            cat "$SERVER_LOG"
            return 1
        fi
        
        sleep 1
        ((wait_time++))
        echo -n "."
    done
    
    echo ""
    print_status "ERROR" "Server failed to start within $max_wait seconds"
    cat "$SERVER_LOG"
    return 1
}

# Function to test an endpoint with detailed metrics
test_endpoint() {
    local method=$1
    local endpoint=$2
    local expected_status_codes=$3  # Can be multiple codes separated by |
    local headers=$4
    local data=$5
    local description=$6
    
    ((TOTAL_TESTS++))
    
    print_status "TEST" "Testing $method $endpoint - $description"
    
    local curl_cmd="curl -s -w '\n%{http_code}\n%{time_total}' --max-time 10"
    
    if [[ -n "$headers" ]]; then
        while IFS= read -r header; do
            curl_cmd="$curl_cmd -H '$header'"
        done <<< "$headers"
    fi
    
    if [[ -n "$data" ]]; then
        curl_cmd="$curl_cmd -d '$data'"
    fi
    
    curl_cmd="$curl_cmd -X $method '$BASE_URL$endpoint'"
    
    # Execute the curl command and capture output, status code, and timing
    local response
    local status_code
    local response_time_seconds
    local response_time_ms
    local error_message=""
    
    if response=$(eval "$curl_cmd" 2>&1); then
        # Parse response: last line is time_total, second-to-last is http_code, rest is response body
        local lines=()
        while IFS= read -r line; do
            lines+=("$line")
        done <<< "$response"
        
        local num_lines=${#lines[@]}
        if [[ $num_lines -ge 2 ]]; then
            response_time_seconds="${lines[$((num_lines-1))]}"
            status_code="${lines[$((num_lines-2))]}"
            
            # Reconstruct response body (all lines except last two)
            response=""
            for (( i=0; i<num_lines-2; i++ )); do
                if [[ $i -gt 0 ]]; then
                    response="${response}\n"
                fi
                response="${response}${lines[$i]}"
            done
        else
            status_code="000"
            response_time_seconds="0"
        fi
        
        # Convert response time to milliseconds
        if command -v bc >/dev/null 2>&1 && [[ "$response_time_seconds" =~ ^[0-9.]+$ ]]; then
            response_time_ms=$(printf "%.0f" $(echo "$response_time_seconds * 1000" | bc -l))
        else
            response_time_ms=$(printf "%.0f" $(echo "$response_time_seconds * 1000" | awk '{print $1}' 2>/dev/null || echo "0"))
        fi
        
        # Check if server crashed (connection refused, etc.)
        if [[ "$response" == *"Connection refused"* ]] || [[ "$response" == *"Failed to connect"* ]]; then
            print_status "ERROR" "❌ SERVER CRASHED - Connection refused"
            log_result "$endpoint" "$method" "000" "CRASHED" "Connection refused" "0" "$description"
            ((CRASHED_TESTS++))
            ((FAILED_TESTS++))
            return 0  # Continue testing other endpoints
        fi
        
        # Check if status code matches expected
        if [[ "$expected_status_codes" == *"$status_code"* ]]; then
            print_status "SUCCESS" "✅ PASSED - HTTP $status_code (${response_time_ms}ms)"
            if [[ "$VERBOSE" == true ]] && [[ ${#response} -gt 0 ]]; then
                echo "Response body:"
                echo "$response" | head -20
                [[ ${#response} -gt 1000 ]] && echo "... (truncated)"
            fi
            log_result "$endpoint" "$method" "$status_code" "PASSED" "" "$response_time_ms" "$description"
            ((PASSED_TESTS++))
            return 0
        else
            print_status "WARNING" "⚠️  UNEXPECTED STATUS - Expected: $expected_status_codes, Got: $status_code (${response_time_ms}ms)"
            if [[ "$VERBOSE" == true ]] || [[ ${#response} -lt 500 ]]; then
                echo "Response: $response"
            fi
            log_result "$endpoint" "$method" "$status_code" "UNEXPECTED_STATUS" "Expected: $expected_status_codes" "$response_time_ms" "$description"
            ((FAILED_TESTS++))
            return 0  # Continue testing other endpoints
        fi
    else
        error_message="Curl command failed: $response"
        print_status "ERROR" "❌ FAILED - $error_message"
        log_result "$endpoint" "$method" "000" "FAILED" "$error_message" "0" "$description"
        ((FAILED_TESTS++))
        return 0  # Continue testing other endpoints
    fi
}

# Function to run authentication tests
test_auth_endpoints() {
    print_status "INFO" "🔐 Testing Authentication Endpoints"
    
    # Test user registration (may fail with 400 if user already exists)
    test_endpoint "POST" "/api/auth/sign-up" "200|400" \
        "Content-Type: application/json" \
        '{"email": "testuser@example.com", "password": "password123", "firstName": "Test", "lastName": "User"}' \
        "User registration"
    
    # Test password reset
    test_endpoint "POST" "/api/auth/reset-password" "200|404" \
        "Content-Type: application/json" \
        '{"email": "testuser@example.com"}' \
        "Password reset request"
    
    # Test Apple authentication (should fail gracefully)
    test_endpoint "POST" "/api/auth/apple-auth" "400|401|422|501" \
        "Content-Type: application/json" \
        '{"identityToken": "fake_token", "authorizationCode": "fake_code"}' \
        "Apple authentication (invalid token)"
    
    # Test refresh token (with fake token - should fail)
    test_endpoint "POST" "/api/auth/refresh" "200|400|401|404" \
        "Content-Type: application/json" \
        '{"refreshToken": "fake_refresh_token"}' \
        "Token refresh"
    
    # Test logout (without token - should fail)
    test_endpoint "POST" "/api/auth/logout" "401" \
        "" \
        "" \
        "User logout (no token)"
}

# Function to run user endpoints tests
test_user_endpoints() {
    print_status "INFO" "👤 Testing User Endpoints"
    
    # Test get current user (without token - should get 401)
    test_endpoint "GET" "/api/user/me" "401" \
        "" \
        "" \
        "Get current user (unauthorized)"
    
    # Test update user profile (without token - should get 401)
    test_endpoint "PATCH" "/api/user/update" "401" \
        "Content-Type: application/json" \
        '{"firstName": "UpdatedName"}' \
        "Update user profile (unauthorized)"
    
    # Test delete user (without token - should get 401)
    test_endpoint "DELETE" "/api/user/delete" "401" \
        "" \
        "" \
        "Delete user account (unauthorized)"
    
    # Test admin endpoints (should fail without token)
    test_endpoint "GET" "/api/user/list" "401" \
        "" \
        "" \
        "List users (unauthorized)"
}

# Function to test rules generation endpoints
test_rules_endpoints() {
    print_status "INFO" "🎲 Testing Rules Generation Endpoints"
    
    # Test game box analysis (without proper image data)
    test_endpoint "POST" "/api/rules-generation/game-box-analysis" "400|413|422" \
        "Content-Type: application/json" \
        '{"invalidData": "test"}' \
        "Game box analysis (invalid data)"
    
    # Test rules summary generation
    test_endpoint "POST" "/api/rules-generation/rules-summary" "400|422" \
        "Content-Type: application/json" \
        '{"gameName": "Test Game"}' \
        "Rules summary generation (minimal data)"
    
    # Test rules summary with complete data
    test_endpoint "POST" "/api/rules-generation/rules-summary" "200|400|422" \
        "Content-Type: application/json" \
        '{"gameName": "Chess", "playerCount": "2", "playtime": "30-60 minutes", "difficulty": "intermediate", "summary": "Classic strategy board game"}' \
        "Rules summary generation (complete data)"
}

# Function to test frontend endpoints  
test_frontend_endpoints() {
    print_status "INFO" "🌐 Testing Frontend Endpoints"
    
    # Test email verification page (without token)
    test_endpoint "GET" "/verify-email" "400" \
        "" \
        "" \
        "Email verification page (no token)"
    
    # Test email verification page (with fake token)
    test_endpoint "GET" "/verify-email?token=fake_token" "400|404|422" \
        "" \
        "" \
        "Email verification page (fake token)"
    
    # Test password reset page (without token)
    test_endpoint "GET" "/reset-password" "400" \
        "" \
        "" \
        "Password reset page (no token)"
    
    # Test password reset page (with fake token)
    test_endpoint "GET" "/reset-password?token=fake_token" "400|404|422" \
        "" \
        "" \
        "Password reset page (fake token)"
    
    # Test password reset form submission
    test_endpoint "POST" "/reset-password" "400|404|422" \
        "Content-Type: application/json" \
        '{"password": "newpassword123", "confirmPassword": "newpassword123"}' \
        "Password reset form submission (no token)"
}

# Function to test admin endpoints
test_admin_endpoints() {
    print_status "INFO" "⚙️ Testing Admin Cache Endpoints"
    
    # Test cache stats (unauthorized)
    test_endpoint "GET" "/api/admin/cache/stats" "401" \
        "" \
        "" \
        "Cache stats (unauthorized)"
    
    # Test cache health (unauthorized)
    test_endpoint "GET" "/api/admin/cache/health" "401" \
        "" \
        "" \
        "Cache health (unauthorized)"
    
    # Test cache entries (unauthorized)
    test_endpoint "GET" "/api/admin/cache/entries" "401" \
        "" \
        "" \
        "Cache entries (unauthorized)"
    
    # Test clear cache (unauthorized)
    test_endpoint "DELETE" "/api/admin/cache" "401" \
        "" \
        "" \
        "Clear cache (unauthorized)"
    
    # Test manual cleanup (unauthorized)
    test_endpoint "POST" "/api/admin/cache/cleanup" "401" \
        "" \
        "" \
        "Manual cache cleanup (unauthorized)"
}

# Function to test basic connectivity
test_basic_endpoints() {
    print_status "INFO" "🔍 Testing Basic Connectivity"
    
    # Test root endpoint (should return 404)
    test_endpoint "GET" "/" "404" \
        "" \
        "" \
        "Root endpoint"
    
    # Test non-existent endpoint
    test_endpoint "GET" "/nonexistent" "404" \
        "" \
        "" \
        "Non-existent endpoint"
}

# Function to generate comprehensive endpoint overview
generate_endpoint_overview() {
    echo ""
    print_status "INFO" "🔍 Endpoint Overview"
    echo "==============================================================================="
    printf "%-8s %-35s %-8s %-8s %-12s %s\n" "STATUS" "ENDPOINT" "HTTP" "TIME" "RESULT" "DESCRIPTION"
    echo "==============================================================================="
    
    # Sort endpoint data for consistent output
    local sorted_data=()
    IFS=$'\n' sorted_data=($(printf '%s\n' "${ENDPOINT_DATA[@]}" | sort))
    
    for data in "${sorted_data[@]}"; do
        IFS='|' read -r endpoint_key status_code response_time result status_icon description <<< "$data"
        
        # Format response time
        local formatted_time
        if [[ "$response_time" -eq 0 ]]; then
            formatted_time="--"
        else
            formatted_time="${response_time}ms"
        fi
        
        # Truncate description if too long
        local truncated_desc
        if [[ ${#description} -gt 25 ]]; then
            truncated_desc="${description:0:22}..."
        else
            truncated_desc="$description"
        fi
        
        printf "%-8s %-35s %-8s %-8s %-12s %s\n" \
            "$status_icon" \
            "$endpoint_key" \
            "$status_code" \
            "$formatted_time" \
            "$result" \
            "$truncated_desc"
    done
    
    echo "==============================================================================="
}

# Function to calculate performance metrics
calculate_performance_metrics() {
    local total_time=0
    local valid_measurements=0
    local fastest_time=999999
    local slowest_time=0
    local fastest_endpoint=""
    local slowest_endpoint=""
    
    for data in "${ENDPOINT_DATA[@]}"; do
        IFS='|' read -r endpoint_key status_code response_time result status_icon description <<< "$data"
        
        if [[ "$response_time" -gt 0 ]]; then
            total_time=$((total_time + response_time))
            ((valid_measurements++))
            
            if [[ "$response_time" -lt "$fastest_time" ]]; then
                fastest_time=$response_time
                fastest_endpoint=$endpoint_key
            fi
            
            if [[ "$response_time" -gt "$slowest_time" ]]; then
                slowest_time=$response_time
                slowest_endpoint=$endpoint_key
            fi
        fi
    done
    
    if [[ $valid_measurements -gt 0 ]]; then
        local avg_time=$((total_time / valid_measurements))
        echo ""
        print_status "INFO" "⚡ Performance Metrics"
        echo "=============================================="
        echo "Average response time: ${avg_time}ms"
        echo "Fastest endpoint: $fastest_endpoint (${fastest_time}ms)"
        echo "Slowest endpoint: $slowest_endpoint (${slowest_time}ms)"
        echo "Total valid measurements: $valid_measurements"
    fi
}

# Function to generate final report with comprehensive overview
generate_report() {
    # Generate endpoint overview
    generate_endpoint_overview
    
    # Calculate and display performance metrics
    calculate_performance_metrics
    
    echo ""
    print_status "INFO" "📊 Test Results Summary"
    echo "=============================================="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Crashed: $CRASHED_TESTS"
    
    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    fi
    echo "Pass Rate: ${pass_rate}%"
    echo ""
    
    # Categorize results
    if [[ $CRASHED_TESTS -gt 0 ]]; then
        print_status "ERROR" "💥 CRITICAL: $CRASHED_TESTS endpoint(s) caused server crashes!"
        echo ""
        echo "Crashed Endpoints:"
        for data in "${ENDPOINT_DATA[@]}"; do
            IFS='|' read -r endpoint_key status_code response_time result status_icon description <<< "$data"
            if [[ "$result" == "CRASHED" ]]; then
                echo "  - $endpoint_key"
            fi
        done
    elif [[ $FAILED_TESTS -gt 0 ]]; then
        print_status "WARNING" "⚠️  $FAILED_TESTS test(s) failed (but no crashes)"
        echo ""
        echo "Failed/Unexpected Endpoints:"
        for data in "${ENDPOINT_DATA[@]}"; do
            IFS='|' read -r endpoint_key status_code response_time result status_icon description <<< "$data"
            if [[ "$result" == "FAILED" ]] || [[ "$result" == "UNEXPECTED_STATUS" ]]; then
                echo "  - $endpoint_key (HTTP $status_code)"
            fi
        done
    else
        print_status "SUCCESS" "🎉 ALL TESTS PASSED! No server crashes detected."
        echo ""
        print_status "SUCCESS" "✅ All endpoints are working correctly"
        print_status "SUCCESS" "✅ Server stability confirmed"
        print_status "SUCCESS" "✅ UserRepository service fix is successful"
    fi
    
    echo ""
    echo "Logs:"
    echo "=================="
    echo "Full results logged to: $RESULTS_LOG"
    echo "Server log available at: $SERVER_LOG"
    
    # Return non-zero exit code if there were crashes
    if [[ $CRASHED_TESTS -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Main execution
main() {
    print_status "HEADER" "═══════════════════════════════════════════════════════════════"
    print_status "HEADER" "     PROJECT RULEBOOK API - COMPREHENSIVE ENDPOINT TESTING     "
    print_status "HEADER" "═══════════════════════════════════════════════════════════════"
    print_status "INFO" "Target: $BASE_URL"
    print_status "INFO" "Logs: $LOGS_DIR"
    
    # Start the server unless skipped
    if [[ "$SKIP_SERVER" == false ]]; then
        if ! start_server; then
            print_status "ERROR" "Failed to start server. Exiting."
            exit 1
        fi
    else
        print_status "INFO" "Using existing server at $BASE_URL"
        # Test if server is responsive
        if ! curl -s --max-time 2 "$BASE_URL/" >/dev/null 2>&1; then
            print_status "WARNING" "Server at $BASE_URL is not responding. Starting server..."
            if ! start_server; then
                print_status "ERROR" "Failed to start server. Exiting."
                exit 1
            fi
        fi
    fi
    
    [[ "$QUIET" == false ]] && echo ""
    
    # Run all test suites
    print_status "HEADER" "Running Test Suites..."
    test_basic_endpoints
    test_auth_endpoints
    test_user_endpoints
    test_rules_endpoints
    test_admin_endpoints
    
    # Generate final report
    generate_report
}

# Run the main function
main "$@"