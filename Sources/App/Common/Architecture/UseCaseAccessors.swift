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
    
    /// Sign-up use case for handling user registration.
    var signUp: SignUpUseCase {
        get async throws {
            try await request.resolveService(SignUpUseCase.self)
        }
    }
    
    /// Sign-in use case for handling user authentication.
    var signIn: SignInUseCase {
        get async throws {
            try await request.resolveService(SignInUseCase.self)
        }
    }
    
    /// Apple Sign-In use case for handling Apple authentication.
    // TODO: Restore when Apple JWT verification is fixed
    // var appleSignIn: AppleSignInUseCase {
    //     get async throws {
    //         try await request.resolveService(AppleSignInUseCase.self)
    //     }
    // }
    
    /// Refresh token use case for handling JWT token refresh.
    var refreshToken: RefreshTokenUseCase {
        get async throws {
            try await request.resolveService(RefreshTokenUseCase.self)
        }
    }
}