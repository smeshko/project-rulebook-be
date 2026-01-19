import Vapor
import NIOCore
import NIOHTTP1
import NIOConcurrencyHelpers

/// HTTP client wrapper that can simulate network failures for resilience testing.
///
/// Use this to test how your application handles various network failure scenarios
/// including timeouts, connection failures, rate limiting, and server errors.
///
/// ## Usage
/// ```swift
/// // In IsolatedTestWorld or test setup
/// let failableClient = FailableHTTPClient(wrapping: app.client, eventLoop: app.eventLoopGroup.next())
///
/// // Simulate timeout
/// failableClient.configure(.timeout)
///
/// // Simulate intermittent failures (every 3rd request fails)
/// failableClient.configure(.intermittent(failEvery: 3))
///
/// // Simulate rate limiting
/// failableClient.configure(.rateLimited(retryAfter: 60))
/// ```
final class FailableHTTPClient: Client, @unchecked Sendable {
    private let realClient: Client
    private let _eventLoop: EventLoop
    private var failureMode: FailureMode = .none
    private var requestCount: Int = 0
    private var requestLog: [ClientRequest] = []
    private let lock = NIOLock()

    /// Failure modes that can be simulated.
    enum FailureMode: Sendable {
        /// No failure - pass through to real client.
        case none

        /// Simulate connection timeout.
        case timeout

        /// Simulate connection refused / unreachable host.
        case connectionRefused

        /// Return a specific HTTP error status.
        case serverError(HTTPStatus)

        /// Fail every N requests (for testing retry logic).
        case intermittent(failEvery: Int)

        /// Simulate rate limiting with Retry-After header.
        case rateLimited(retryAfter: Int)

        /// Fail the first N requests, then succeed.
        case failFirst(count: Int)

        /// Return malformed/empty response body.
        case malformedResponse

        /// Simulate slow response (delayed success).
        case slowResponse(delaySeconds: Double)
    }

    /// Error types for simulated failures.
    enum SimulatedError: Error, LocalizedError {
        case timeout
        case connectionRefused
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .timeout:
                return "Simulated timeout: remote host did not respond"
            case .connectionRefused:
                return "Simulated connection refused: could not connect to host"
            case .malformedResponse:
                return "Simulated malformed response from server"
            }
        }
    }

    /// Creates a new failable HTTP client wrapping an existing client.
    ///
    /// - Parameters:
    ///   - client: The real HTTP client to wrap.
    ///   - eventLoop: Event loop for creating futures.
    init(wrapping client: Client, eventLoop: EventLoop) {
        self.realClient = client
        self._eventLoop = eventLoop
    }

    /// Configure the failure mode for subsequent requests.
    ///
    /// - Parameter mode: The failure mode to simulate.
    func configure(_ mode: FailureMode) {
        lock.withLock {
            self.failureMode = mode
            self.requestCount = 0
        }
    }

    /// Reset to normal operation (no failures).
    func reset() {
        lock.withLock {
            self.failureMode = .none
            self.requestCount = 0
            self.requestLog.removeAll()
        }
    }

    /// Get the number of requests made since last reset.
    var totalRequestCount: Int {
        lock.withLock { requestCount }
    }

    /// Get all requests made since last reset (for verification).
    var requests: [ClientRequest] {
        lock.withLock { requestLog }
    }

    // MARK: - Client Protocol

    var eventLoop: EventLoop {
        _eventLoop
    }

    func delegating(to eventLoop: EventLoop) -> Client {
        FailableHTTPClient(wrapping: realClient.delegating(to: eventLoop), eventLoop: eventLoop)
    }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let (mode, count) = lock.withLock { () -> (FailureMode, Int) in
            requestCount += 1
            requestLog.append(request)
            return (failureMode, requestCount)
        }

        switch mode {
        case .none:
            return realClient.send(request)

        case .timeout:
            return eventLoop.makeFailedFuture(SimulatedError.timeout)

        case .connectionRefused:
            return eventLoop.makeFailedFuture(SimulatedError.connectionRefused)

        case .serverError(let status):
            return makeErrorResponse(status: status, request: request)

        case .intermittent(let failEvery):
            if count % failEvery == 0 {
                return eventLoop.makeFailedFuture(SimulatedError.timeout)
            }
            return realClient.send(request)

        case .rateLimited(let retryAfter):
            return makeRateLimitedResponse(retryAfter: retryAfter, request: request)

        case .failFirst(let failCount):
            if count <= failCount {
                return eventLoop.makeFailedFuture(SimulatedError.connectionRefused)
            }
            return realClient.send(request)

        case .malformedResponse:
            return eventLoop.makeFailedFuture(SimulatedError.malformedResponse)

        case .slowResponse(let delaySeconds):
            let promise = eventLoop.makePromise(of: ClientResponse.self)
            eventLoop.scheduleTask(in: .milliseconds(Int64(delaySeconds * 1000))) {
                self.realClient.send(request).cascade(to: promise)
            }
            return promise.futureResult
        }
    }

    // MARK: - Private Helpers

    private func makeErrorResponse(status: HTTPStatus, request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        var response = ClientResponse()
        response.status = status
        response.headers.add(name: .contentType, value: "application/json")

        let errorBody = """
        {"error": true, "reason": "Simulated \(status.code) error"}
        """
        var buffer = ByteBufferAllocator().buffer(capacity: errorBody.utf8.count)
        buffer.writeString(errorBody)
        response.body = buffer

        return eventLoop.makeSucceededFuture(response)
    }

    private func makeRateLimitedResponse(retryAfter: Int, request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        var response = ClientResponse()
        response.status = .tooManyRequests
        response.headers.add(name: "Retry-After", value: "\(retryAfter)")
        response.headers.add(name: .contentType, value: "application/json")

        let errorBody = """
        {"error": true, "reason": "Rate limit exceeded", "retryAfter": \(retryAfter)}
        """
        var buffer = ByteBufferAllocator().buffer(capacity: errorBody.utf8.count)
        buffer.writeString(errorBody)
        response.body = buffer

        return eventLoop.makeSucceededFuture(response)
    }
}

// MARK: - Test Assertions

extension FailableHTTPClient {
    /// Verify a specific number of requests were made.
    func expectRequestCount(_ expected: Int, file: StaticString = #file, line: UInt = #line) {
        let actual = totalRequestCount
        precondition(actual == expected, "Expected \(expected) requests but got \(actual)", file: file, line: line)
    }

    /// Verify the last request was to a specific URL path.
    func expectLastRequestPath(_ expectedPath: String, file: StaticString = #file, line: UInt = #line) {
        guard let lastRequest = requests.last else {
            preconditionFailure("No requests recorded", file: file, line: line)
        }
        let actualPath = lastRequest.url.path
        precondition(actualPath == expectedPath, "Expected path '\(expectedPath)' but got '\(actualPath)'", file: file, line: line)
    }
}
