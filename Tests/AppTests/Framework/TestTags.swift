import Testing

// MARK: - Test Priority Tags

/// Test priority tags for selective execution in CI pipelines.
///
/// Priority levels follow a risk-based approach:
/// - **P0 (Critical)**: Must pass before any merge. Core user journeys that would cause immediate user impact if broken.
/// - **P1 (Core)**: Run on every PR. Important functionality but not blocking critical paths.
/// - **P2 (Extended)**: Run nightly. Comprehensive coverage including edge cases.
/// - **P3 (Edge)**: Run weekly. Rare scenarios, unusual inputs, defensive coverage.
///
/// ## Usage
/// ```swift
/// @Test("User can sign up", .tags(.p0Critical, .auth, .integration))
/// func signupHappyPath() async throws { ... }
/// ```
///
/// ## CI Execution
/// ```bash
/// # P0 only (fast gate, < 2 min)
/// swift test --filter "p0Critical"
///
/// # P0 + P1 (PR checks, < 10 min)
/// swift test --filter "p0Critical|p1Core"
/// ```
extension Tag {
    // MARK: Priority Tags

    /// P0: Critical path tests - must pass before merge.
    /// Examples: signup, login, core API endpoints, payment flows.
    @Tag static var p0Critical: Self

    /// P1: Core functionality tests - run on every PR.
    /// Examples: CRUD operations, validation logic, authorization.
    @Tag static var p1Core: Self

    /// P2: Extended coverage tests - run nightly.
    /// Examples: error handling, edge cases, boundary conditions.
    @Tag static var p2Extended: Self

    /// P3: Edge case tests - run weekly.
    /// Examples: unicode handling, extreme inputs, race conditions.
    @Tag static var p3Edge: Self

    // MARK: Domain Tags

    /// Authentication and authorization related tests.
    @Tag static var auth: Self

    /// Rules generation and AI service tests.
    @Tag static var rulesGeneration: Self

    /// AI/LLM service integration tests.
    @Tag static var aiServices: Self

    /// Database and repository tests.
    @Tag static var database: Self

    /// User management tests.
    @Tag static var users: Self

    /// Caching related tests.
    @Tag static var caching: Self

    /// Email service tests.
    @Tag static var email: Self

    /// Remote configuration tests.
    @Tag static var remoteConfig: Self

    /// Receipts and in-app purchase related tests.
    @Tag static var receipts: Self

    // MARK: Test Type Tags

    /// Integration tests - full application stack with HTTP.
    @Tag static var integration: Self

    /// Unit tests - isolated component testing.
    @Tag static var unit: Self

    /// Contract tests - API schema validation.
    @Tag static var contract: Self

    /// Performance tests - timing and throughput.
    @Tag static var performance: Self

    /// Security tests - auth, input validation, injection.
    @Tag static var security: Self

    // MARK: Condition Tags

    /// Known flaky test - needs investigation.
    /// Tests with this tag are excluded from PR checks.
    @Tag static var flaky: Self

    /// Slow test (> 5 seconds execution).
    /// Tests with this tag may be excluded from fast gate.
    @Tag static var slow: Self

    /// Requires external network access.
    /// Tests with this tag are skipped in offline CI environments.
    @Tag static var requiresNetwork: Self

    /// Requires specific environment variables.
    @Tag static var requiresEnv: Self
}

// MARK: - Tag Combinations

/// Pre-defined tag combinations for common test scenarios.
///
/// Use these in test suites to apply consistent tagging:
/// ```swift
/// @Test("Signup flow", .tags(.criticalAuth))
/// func testSignup() async throws { ... }
/// ```
extension Tag {
    /// Critical authentication test (P0 + auth + integration).
    static var criticalAuth: [Tag] { [.p0Critical, .auth, .integration] }

    /// Core API test (P1 + integration).
    static var coreAPI: [Tag] { [.p1Core, .integration] }

    /// Database unit test (P1 + database + unit).
    static var dbUnit: [Tag] { [.p1Core, .database, .unit] }

    /// AI service test (P2 + aiServices + integration).
    static var aiTest: [Tag] { [.p2Extended, .aiServices, .integration] }
}
