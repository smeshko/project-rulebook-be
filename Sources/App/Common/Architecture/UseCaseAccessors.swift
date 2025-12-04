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

    /// Rules generation-related use cases.
    var rules: RulesUseCases {
        RulesUseCases(request: request)
    }
}

/// Namespace for rules generation-related use cases.
struct RulesUseCases {
    let request: Request

    /// Analyze game box use case for AI-powered game identification.
    var analyzeGameBox: AnalyzeGameBoxUseCase {
        get async throws {
            try await request.resolveService(AnalyzeGameBoxUseCase.self)
        }
    }

    /// Generate rules use case for AI-powered rules generation.
    var generateRules: GenerateRulesUseCase {
        get async throws {
            try await request.resolveService(GenerateRulesUseCase.self)
        }
    }
}

