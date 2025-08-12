import Vapor

/// Convenience accessors for use cases through Request extension.
///
/// This provides a clean, namespaced API for accessing use cases from controllers:
/// ```swift
/// let useCase = try await req.useCases.auth.logout
/// ```
extension Request {
    /// Root accessor for all use cases.
    var useCases: UseCases {
        UseCases(request: self)
    }
}

/// Root namespace for all use case accessors.
struct UseCases {
    let request: Request
    
    /// Authentication-related use cases.
    var auth: AuthUseCases {
        AuthUseCases(request: request)
    }
    
    // Future namespaces will be added here:
    // var user: UserUseCases { UserUseCases(request: request) }
    // var rules: RulesUseCases { RulesUseCases(request: request) }
}

/// Namespace for authentication-related use cases.
struct AuthUseCases {
    let request: Request
    
    /// Logout use case for handling user logout.
    var logout: LogoutUseCase {
        get async throws {
            try await request.resolveService(LogoutUseCase.self)
        }
    }
    
    // Future authentication use cases will be added here:
    // var signUp: SignUpUseCase { get async throws { ... } }
    // var signIn: SignInUseCase { get async throws { ... } }
    // var refreshToken: RefreshTokenUseCase { get async throws { ... } }
}