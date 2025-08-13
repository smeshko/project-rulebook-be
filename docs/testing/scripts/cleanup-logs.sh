#!/bin/bash

# =============================================================================
# Log Cleanup Script for Testing Infrastructure
# =============================================================================
# Purpose: Manages log file rotation and cleanup for testing logs
# Author: Project Rulebook Team
# Version: 1.0.0
# Last Updated: 2025-08-13
# =============================================================================
#
# USAGE:
#   ./cleanup-logs.sh [options]
#
# OPTIONS:
#   -h, --help        Show this help message
#   -a, --archive     Archive old logs (don't delete)
#   -d, --days DAYS   Archive logs older than DAYS (default: 7)
#   -c, --compress    Compress archived logs
#   -f, --force       Delete all logs without archiving
#
# EXAMPLES:
#   ./cleanup-logs.sh              # Archive logs older than 7 days
#   ./cleanup-logs.sh -d 30        # Archive logs older than 30 days
#   ./cleanup-logs.sh -a -c        # Archive and compress old logs
#   ./cleanup-logs.sh -f           # Delete all logs (use with caution!)
#
# =============================================================================

set -e

# Script directory detection
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGS_DIR="$( cd "$SCRIPT_DIR/../logs" && pwd )"
ARCHIVE_DIR="$LOGS_DIR/archive"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default configuration
ARCHIVE_MODE=true
DAYS_OLD=7
COMPRESS=false
FORCE_DELETE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            grep "^#" "$0" | grep -E "(USAGE|OPTIONS|EXAMPLES):" -A 20 | grep -v "grep" | cut -c3-
            exit 0
            ;;
        -a|--archive)
            ARCHIVE_MODE=true
            shift
            ;;
        -d|--days)
            DAYS_OLD="$2"
            shift 2
            ;;
        -c|--compress)
            COMPRESS=true
            shift
            ;;
        -f|--force)
            FORCE_DELETE=true
            ARCHIVE_MODE=false
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
    esac
}

# Main cleanup function
cleanup_logs() {
    print_message "INFO" "Starting log cleanup in: $LOGS_DIR"
    
    # Count current log files
    local log_count=$(find "$LOGS_DIR" -maxdepth 1 -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ $log_count -eq 0 ]]; then
        print_message "INFO" "No log files found to clean up"
        return 0
    fi
    
    print_message "INFO" "Found $log_count log file(s)"
    
    # Force delete mode
    if [[ "$FORCE_DELETE" == true ]]; then
        print_message "WARNING" "Force delete mode - removing all logs"
        read -p "Are you sure you want to delete all logs? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$LOGS_DIR"/*.log
            print_message "SUCCESS" "All log files deleted"
        else
            print_message "INFO" "Operation cancelled"
        fi
        return 0
    fi
    
    # Archive mode
    if [[ "$ARCHIVE_MODE" == true ]]; then
        # Create archive directory if it doesn't exist
        mkdir -p "$ARCHIVE_DIR"
        
        # Find logs older than specified days
        local old_logs=$(find "$LOGS_DIR" -maxdepth 1 -name "*.log" -mtime +$DAYS_OLD 2>/dev/null)
        
        if [[ -z "$old_logs" ]]; then
            print_message "INFO" "No logs older than $DAYS_OLD days found"
            return 0
        fi
        
        print_message "INFO" "Archiving logs older than $DAYS_OLD days"
        
        # Archive old logs
        local archived_count=0
        for log_file in $old_logs; do
            local basename=$(basename "$log_file")
            local archive_name="$ARCHIVE_DIR/${basename%.log}-$(date -r "$log_file" '+%Y%m%d').log"
            
            mv "$log_file" "$archive_name"
            ((archived_count++))
            print_message "SUCCESS" "Archived: $basename"
        done
        
        print_message "SUCCESS" "Archived $archived_count log file(s)"
        
        # Compress if requested
        if [[ "$COMPRESS" == true ]] && [[ $archived_count -gt 0 ]]; then
            print_message "INFO" "Compressing archived logs"
            
            local archive_date=$(date '+%Y%m%d-%H%M%S')
            local archive_file="$ARCHIVE_DIR/logs-archive-$archive_date.tar.gz"
            
            # Find all uncompressed logs in archive
            local uncompressed=$(find "$ARCHIVE_DIR" -name "*.log" 2>/dev/null)
            
            if [[ -n "$uncompressed" ]]; then
                tar -czf "$archive_file" -C "$ARCHIVE_DIR" $(cd "$ARCHIVE_DIR" && ls *.log 2>/dev/null)
                
                # Remove uncompressed logs after successful compression
                if [[ -f "$archive_file" ]]; then
                    rm -f "$ARCHIVE_DIR"/*.log
                    print_message "SUCCESS" "Compressed logs to: $(basename "$archive_file")"
                else
                    print_message "ERROR" "Failed to compress logs"
                fi
            fi
        fi
    fi
}

# Show current log status
show_log_status() {
    print_message "INFO" "Current log status:"
    
    # Count logs
    local current_logs=$(find "$LOGS_DIR" -maxdepth 1 -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    local archived_logs=$(find "$ARCHIVE_DIR" -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    local compressed_archives=$(find "$ARCHIVE_DIR" -name "*.tar.gz" 2>/dev/null | wc -l | tr -d ' ')
    
    echo "  Current logs: $current_logs"
    echo "  Archived logs: $archived_logs"
    echo "  Compressed archives: $compressed_archives"
    
    # Calculate total size
    local current_size=$(du -sh "$LOGS_DIR" 2>/dev/null | cut -f1)
    echo "  Total size: $current_size"
}

# Main execution
main() {
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    echo -e "${BLUE}     Log Cleanup Utility for Testing Logs      ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════${NC}"
    
    # Show status before cleanup
    show_log_status
    echo
    
    # Perform cleanup
    cleanup_logs
    echo
    
    # Show status after cleanup
    show_log_status
    
    print_message "SUCCESS" "Log cleanup completed"
}

# Run main function
main "$@"