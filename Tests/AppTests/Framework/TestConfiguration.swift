import Foundation

// MARK: - Test Stage Configuration

/// Test execution configuration for different CI pipeline stages.
///
/// Use these configurations to run appropriate test subsets at different
/// stages of your CI/CD pipeline, balancing speed vs coverage.
///
/// ## Recommended Pipeline Structure
///
/// ```
/// PR Opened → Fast Gate (P0, < 2 min)
///     ↓
/// PR Check (P0 + P1, < 10 min)
///     ↓
/// Merge to main → Nightly Suite (All tests)
///     ↓
/// Weekly → Performance + Edge Cases
/// ```
///
/// ## Usage
/// ```bash
/// # Fast gate
/// swift test --filter "$(TestStage.fastGate.filterPattern)"
///
/// # PR check
/// swift test --filter "$(TestStage.prCheck.filterPattern)"
/// ```
enum TestStage: String, CaseIterable {
    /// Fast gate: P0 critical tests only.
    /// Target: < 2 minutes execution.
    /// Run: On every PR, before any other checks.
    case fastGate

    /// PR check: P0 + P1 core tests.
    /// Target: < 10 minutes execution.
    /// Run: After fast gate passes, required for merge.
    case prCheck

    /// Nightly: All tests except known flaky.
    /// Target: < 30 minutes execution.
    /// Run: Nightly on main branch.
    case nightly

    /// Full: Complete test suite including flaky.
    /// Target: No limit.
    /// Run: Weekly or on-demand.
    case full

    /// Performance: Performance tests only.
    /// Target: Variable.
    /// Run: Before release or on performance-critical changes.
    case performance

    /// Contract: API contract/schema tests only.
    /// Target: < 5 minutes.
    /// Run: When API changes are detected.
    case contract

    // MARK: - Configuration

    /// Tags to include in this stage.
    var includedTags: [String] {
        switch self {
        case .fastGate:
            return ["p0Critical"]
        case .prCheck:
            return ["p0Critical", "p1Core"]
        case .nightly:
            return [] // All tags (filtered by exclusions)
        case .full:
            return [] // Absolutely all tests
        case .performance:
            return ["performance"]
        case .contract:
            return ["contract"]
        }
    }

    /// Tags to exclude from this stage.
    var excludedTags: [String] {
        switch self {
        case .fastGate:
            return ["flaky", "slow", "performance", "p2Extended", "p3Edge"]
        case .prCheck:
            return ["flaky", "slow", "performance", "p3Edge"]
        case .nightly:
            return ["flaky"]
        case .full:
            return [] // Include everything, even flaky
        case .performance:
            return []
        case .contract:
            return ["flaky"]
        }
    }

    /// Swift test filter pattern for command line.
    var filterPattern: String {
        if includedTags.isEmpty {
            if excludedTags.isEmpty {
                return "" // Run all
            }
            // Exclude pattern (negative lookahead not supported, use manual filtering)
            return excludedTags.joined(separator: "|")
        }
        return includedTags.joined(separator: "|")
    }

    /// Recommended parallel worker count.
    var parallelWorkers: Int {
        switch self {
        case .fastGate:
            return 4
        case .prCheck:
            return 2
        case .nightly:
            return 1 // Serial for reliability
        case .full:
            return 1
        case .performance:
            return 1 // Must be serial for accurate timing
        case .contract:
            return 4
        }
    }

    /// Timeout in minutes for this stage.
    var timeoutMinutes: Int {
        switch self {
        case .fastGate:
            return 5
        case .prCheck:
            return 15
        case .nightly:
            return 30
        case .full:
            return 60
        case .performance:
            return 30
        case .contract:
            return 10
        }
    }

    /// Human-readable description.
    var description: String {
        switch self {
        case .fastGate:
            return "Fast Gate (P0 Critical)"
        case .prCheck:
            return "PR Check (P0 + P1 Core)"
        case .nightly:
            return "Nightly Suite (All except flaky)"
        case .full:
            return "Full Suite (Everything)"
        case .performance:
            return "Performance Tests"
        case .contract:
            return "Contract/Schema Tests"
        }
    }
}

// MARK: - Burn-In Configuration

/// Configuration for burn-in testing of new or flaky tests.
///
/// Burn-in runs tests multiple times to detect intermittent failures
/// before they pollute the main test suite.
struct BurnInConfiguration {
    /// Number of iterations to run.
    let iterations: Int

    /// Whether to fail fast on first failure.
    let failFast: Bool

    /// Tags to target for burn-in.
    let targetTags: [String]

    /// Default burn-in for new tests.
    static let newTests = BurnInConfiguration(
        iterations: 10,
        failFast: true,
        targetTags: ["p1Core"]
    )

    /// Aggressive burn-in for suspected flaky tests.
    static let flakyInvestigation = BurnInConfiguration(
        iterations: 25,
        failFast: false,
        targetTags: ["flaky"]
    )

    /// Pre-release burn-in.
    static let preRelease = BurnInConfiguration(
        iterations: 5,
        failFast: true,
        targetTags: ["p0Critical", "p1Core"]
    )
}

// MARK: - Test Environment

/// Environment variables for test configuration.
enum TestEnvironment {
    /// Check if running in CI environment.
    static var isCI: Bool {
        ProcessInfo.processInfo.environment["CI"] == "true" ||
        ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
    }

    /// Current test stage from environment.
    static var currentStage: TestStage? {
        guard let stageName = ProcessInfo.processInfo.environment["TEST_STAGE"] else {
            return nil
        }
        return TestStage(rawValue: stageName)
    }

    /// Whether to skip slow tests.
    static var skipSlowTests: Bool {
        ProcessInfo.processInfo.environment["SKIP_SLOW_TESTS"] == "true"
    }

    /// Whether to skip network-dependent tests.
    static var skipNetworkTests: Bool {
        ProcessInfo.processInfo.environment["SKIP_NETWORK_TESTS"] == "true"
    }

    /// Custom test timeout override (in seconds).
    static var timeoutOverride: Int? {
        guard let value = ProcessInfo.processInfo.environment["TEST_TIMEOUT"] else {
            return nil
        }
        return Int(value)
    }
}

// MARK: - Test Metrics

/// Tracks test execution metrics for reporting.
actor TestMetrics {
    static let shared = TestMetrics()

    private var testCount: Int = 0
    private var passCount: Int = 0
    private var failCount: Int = 0
    private var skipCount: Int = 0
    private var startTime: Date?
    private var testDurations: [String: TimeInterval] = [:]

    func startSuite() {
        startTime = Date()
        testCount = 0
        passCount = 0
        failCount = 0
        skipCount = 0
        testDurations.removeAll()
    }

    func recordTestStart(_ testName: String) {
        testCount += 1
    }

    func recordTestPass(_ testName: String, duration: TimeInterval) {
        passCount += 1
        testDurations[testName] = duration
    }

    func recordTestFail(_ testName: String, duration: TimeInterval) {
        failCount += 1
        testDurations[testName] = duration
    }

    func recordTestSkip(_ testName: String) {
        skipCount += 1
    }

    func generateReport() -> TestReport {
        let totalDuration = startTime.map { Date().timeIntervalSince($0) } ?? 0
        let slowTests = testDurations.filter { $0.value > 5.0 }
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { TestReport.SlowTest(name: $0.key, duration: $0.value) }

        return TestReport(
            totalTests: testCount,
            passed: passCount,
            failed: failCount,
            skipped: skipCount,
            totalDuration: totalDuration,
            slowestTests: Array(slowTests)
        )
    }
}

/// Test execution report.
struct TestReport {
    let totalTests: Int
    let passed: Int
    let failed: Int
    let skipped: Int
    let totalDuration: TimeInterval
    let slowestTests: [SlowTest]

    struct SlowTest {
        let name: String
        let duration: TimeInterval
    }

    var passRate: Double {
        guard totalTests > 0 else { return 0 }
        return Double(passed) / Double(totalTests) * 100
    }

    var summary: String {
        """
        Test Report
        ===========
        Total: \(totalTests) | Passed: \(passed) | Failed: \(failed) | Skipped: \(skipped)
        Pass Rate: \(String(format: "%.1f", passRate))%
        Duration: \(String(format: "%.1f", totalDuration))s

        Slowest Tests:
        \(slowestTests.map { "  - \($0.name): \(String(format: "%.2f", $0.duration))s" }.joined(separator: "\n"))
        """
    }
}
