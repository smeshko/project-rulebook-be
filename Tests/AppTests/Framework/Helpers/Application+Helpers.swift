@testable import App
import VaporTesting

extension Application {
    // Authenticated test method
    @discardableResult
    func test<C: Content>(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        accessToken: String? = nil,
        user: UserAccountModel? = nil,
        content: C,
        beforeRequest: (inout TestingHTTPRequest) async throws -> () = { _ in },
        afterResponse: (TestingHTTPResponse) async throws -> () = { _ in },
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> TestingApplicationTester {
        var headers = headers
        
        if let token = accessToken {
            headers.add(name: "Authorization", value: "Bearer \(token)")
        } else if let user = user {
            let payload = try TokenPayload(with: user)
            let accessToken = try self.jwt.signers.sign(payload)
            
            headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        }
        
        return try await test(method, path, headers: headers, beforeRequest: { req in
            try await beforeRequest(&req)
            try req.content.encode(content)
        }, afterResponse: afterResponse)
    }
    
    @discardableResult
    func test(
        _ method: HTTPMethod,
        _ path: String,
        headers: HTTPHeaders = [:],
        user: UserAccountModel,
        afterResponse: (TestingHTTPResponse) async throws -> () = { _ in },
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> TestingApplicationTester {
        let payload = try TokenPayload(with: user)
        let accessToken = try self.jwt.signers.sign(payload)
        var headers = headers
        headers.add(name: "Authorization", value: "Bearer \(accessToken)")
        return try await test(method, path, headers: headers, afterResponse: afterResponse)
    }
}
