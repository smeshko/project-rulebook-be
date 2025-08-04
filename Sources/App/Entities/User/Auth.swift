import Foundation

public enum Auth {}

public extension Auth {
    enum Login {
        public struct Request: Codable, Equatable, Sendable {
            public let email: String
            public let password: String
            
            public init(
                email: String,
                password: String
            ) {
                self.email = email
                self.password = password
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let token: TokenRefresh.Response
            public let user: User.Detail.Response
            
            public init(
                token: TokenRefresh.Response,
                user: User.Detail.Response
            ) {
                self.token = token
                self.user = user
            }
        }
    }
    
    enum SignUp {
        public struct Request: Codable, Equatable, Sendable {
            public let email: String
            public let password: String
            public let firstName: String?
            public let lastName: String?

            public init(
                email: String,
                password: String,
                firstName: String? = nil,
                lastName: String? = nil
            ) {
                self.email = email
                self.password = password
                self.firstName = firstName
                self.lastName = lastName
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let token: TokenRefresh.Response
            public let user: User.Detail.Response

            public init(
                token: TokenRefresh.Response,
                user: User.Detail.Response
            ) {
                self.token = token
                self.user = user
            }
        }
    }
    
    enum PasswordReset {
        public struct Request: Codable, Equatable, Sendable {
            public let email: String
            
            public init(email: String) {
                self.email = email
            }
        }
    }
    
    enum TokenRefresh {
        public struct Request: Codable, Equatable, Sendable {
            public let refreshToken: String
            
            public init(refreshToken: String) {
                self.refreshToken = refreshToken
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let refreshToken: String
            public let accessToken: String
            
            public init(
                refreshToken: String,
                accessToken: String
            ) {
                self.refreshToken = refreshToken
                self.accessToken = accessToken
            }
        }
    }
    
    enum Apple {
        public struct Request: Codable, Equatable, Sendable {
            public let firstName: String?
            public let lastName: String?
            public let appleIdentityToken: String
            
            public init(
                firstName: String? = nil,
                lastName: String? = nil,
                appleIdentityToken: String
            ) {
                self.firstName = firstName
                self.lastName = lastName
                self.appleIdentityToken = appleIdentityToken
            }
        }
        
        public struct Response: Codable, Equatable, Sendable {
            public let token: TokenRefresh.Response
            public let user: User.Detail.Response

            public init(
                token: TokenRefresh.Response,
                user: User.Detail.Response
            ) {
                self.token = token
                self.user = user
            }
        }
    }
}
