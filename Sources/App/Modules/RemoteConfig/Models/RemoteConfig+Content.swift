import Vapor

import Foundation

enum RemoteConfig {
    // Value wrapper that includes type information for clients
    struct ConfigValue: Content, Sendable {
        let value: String
        let type: ConfigValueType
    }

    // Public GET response - matches acceptance criteria structure
    // Uses [String: Any] for dynamic JSON values, encoded manually
    struct GetResponse: Sendable {
        let featureFlags: [String: Any]
        let settings: [String: Any]
        let version: String

        init(featureFlags: [String: Any], settings: [String: Any], version: String) {
            self.featureFlags = featureFlags
            self.settings = settings
            self.version = version
        }
    }

    // Admin update request
    struct UpdateRequest: Content, Sendable {
        let key: String
        let value: String
        let type: ConfigValueType
    }

    // Admin update response
    struct UpdateResponse: Content, Sendable {
        let success: Bool
        let key: String
        let message: String
    }
}

// Manual encoding for GetResponse to support [String: Any]
extension RemoteConfig.GetResponse: AsyncResponseEncodable {
    func encodeResponse(for request: Request) async throws -> Response {
        let json: [String: Any] = [
            "featureFlags": featureFlags,
            "settings": settings,
            "version": version
        ]

        let data = try JSONSerialization.data(withJSONObject: json)
        var headers = HTTPHeaders()
        headers.contentType = .json
        return Response(status: .ok, headers: headers, body: .init(data: data))
    }
}
