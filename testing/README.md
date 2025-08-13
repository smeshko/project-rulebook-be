# Testing Infrastructure

This directory contains all testing-related assets for the Project Rulebook Vapor backend, including automated test scripts, API collections, logs, and testing reports.

## Directory Structure

```
testing/
├── scripts/          # Automated testing scripts
├── logs/            # Test execution logs
├── collections/     # API testing collections (Postman, etc.)
└── reports/         # Test execution reports and metrics
```

## Scripts

### test-endpoints.sh
Comprehensive endpoint testing script that validates all API endpoints for stability and correctness.

**Features:**
- Tests all API endpoints systematically
- Detects server crashes and errors
- Generates detailed performance metrics
- Creates comprehensive test reports
- Supports continuous testing during development

**Usage:**
```bash
# Run from project root
./testing/scripts/test-endpoints.sh

# Or from testing directory
cd testing
./scripts/test-endpoints.sh
```

**Output:**
- Real-time test execution status
- Performance metrics (response times)
- Pass/fail statistics
- Detailed logs in `logs/` directory

## Collections

### Project-Rulebook-API-Testing.postman_collection.json
Complete Postman collection for API testing with environment variables and test scripts.

**Features:**
- Organized by modules (Auth, Rules Generation, Cache Admin)
- Built-in test scripts for response validation
- Token management for authenticated endpoints
- Environment variable support

**Setup:**
1. Import collection into Postman
2. Configure environment variables:
   - `base_url`: http://localhost:8080
   - `admin_email`: root@localhost.com
   - `admin_password`: ChangeMe1
3. Run "Admin Login" first to get tokens
4. Test other endpoints with stored tokens

## Logs

Test execution logs are automatically generated and stored here:

- `endpoint-test-server.log` - Server output during testing
- `endpoint-test-results.log` - Detailed test results with timestamps
- `server.log` - General server logs
- `test-server.log` - Test-specific server logs

### Log Rotation

To prevent log files from growing too large, consider implementing these practices:

1. **Manual Cleanup** (before each test run):
```bash
rm -f testing/logs/*.log
```

2. **Archive Old Logs**:
```bash
# Create archive directory if it doesn't exist
mkdir -p testing/logs/archive

# Move logs older than 7 days
find testing/logs -name "*.log" -mtime +7 -exec mv {} testing/logs/archive/ \;
```

3. **Compress Archives**:
```bash
# Compress archived logs
tar -czf testing/logs/archive/logs-$(date +%Y%m%d).tar.gz testing/logs/archive/*.log
rm testing/logs/archive/*.log
```

## Reports

Test execution reports and metrics will be generated here. Future enhancements may include:
- HTML test reports
- Coverage reports
- Performance benchmarks
- Trend analysis

## Quick Start Testing Guide

### 1. Unit Tests (Swift)
```bash
# Run all unit tests
swift test

# Run specific test file
swift test --filter AuthenticationTests

# Run with coverage
swift test --enable-code-coverage
```

### 2. Integration Tests
```bash
# Start server
swift run App serve --hostname 0.0.0.0 --port 8080

# In another terminal, run endpoint tests
./testing/scripts/test-endpoints.sh
```

### 3. API Testing with Postman
```bash
# Using Newman (Postman CLI)
npm install -g newman
newman run testing/collections/Project-Rulebook-API-Testing.postman_collection.json \
  --environment testing/collections/environment.json
```

### 4. Load Testing
```bash
# Using Apache Bench (ab)
ab -n 1000 -c 10 http://localhost:8080/api/auth/sign-in

# Using wrk
wrk -t4 -c100 -d30s http://localhost:8080/
```

## Testing Best Practices

1. **Always run tests before committing**
   ```bash
   swift test && ./testing/scripts/test-endpoints.sh
   ```

2. **Keep logs organized**
   - Archive old logs regularly
   - Review logs for patterns and issues
   - Clear logs before major test runs

3. **Update collections when APIs change**
   - Export updated Postman collection after changes
   - Document any new environment variables
   - Update test scripts as needed

4. **Monitor test performance**
   - Track response time trends
   - Identify slow endpoints
   - Optimize based on metrics

## Continuous Integration

For CI/CD pipelines, use these commands:

```yaml
# Example GitHub Actions workflow
- name: Run Tests
  run: |
    swift test
    ./testing/scripts/test-endpoints.sh
    
- name: Archive Test Results
  uses: actions/upload-artifact@v2
  with:
    name: test-logs
    path: testing/logs/
```

## Troubleshooting

### Common Issues

1. **Port Already in Use**
   ```bash
   # Kill process using port 8080
   lsof -ti:8080 | xargs kill -9
   ```

2. **Permission Denied for Scripts**
   ```bash
   chmod +x testing/scripts/*.sh
   ```

3. **Server Won't Start**
   - Check logs in `testing/logs/`
   - Ensure database is running (if using PostgreSQL)
   - Verify environment variables are set

## Contributing

When adding new test scripts or collections:
1. Place scripts in `testing/scripts/`
2. Store collections in `testing/collections/`
3. Update this README with usage instructions
4. Ensure scripts are executable (`chmod +x`)
5. Add appropriate error handling and logging