@testable import App
import VaporTesting
import XCTest

func XCTAssertResponseError(_ res: TestingHTTPResponse, _ error: AppError, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(res.status, error.status, file: file, line: line)
    XCTAssertContent(ErrorResponse.self, res) { errorContent in
        XCTAssertEqual(errorContent.errorIdentifier, error.identifier, file: file, line: line)
        XCTAssertEqual(errorContent.reason, error.reason, file: file, line: line)
    }
}
