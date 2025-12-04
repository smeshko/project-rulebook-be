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

    /// Cache administration-related use cases.
    var cacheAdmin: CacheAdminUseCases {
        CacheAdminUseCases(request: request)
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

/// Namespace for cache administration-related use cases.
struct CacheAdminUseCases {
    let request: Request
    
    /// Get cache statistics use case for retrieving cache performance metrics.
    var getStats: GetCacheStatsUseCase {
        get async throws {
            try await request.resolveService(GetCacheStatsUseCase.self)
        }
    }
    
    /// Clear cache use case for removing all cache entries.
    var clearCache: ClearCacheUseCase {
        get async throws {
            try await request.resolveService(ClearCacheUseCase.self)
        }
    }
    
    /// Get cache entries use case for listing cached entries with metadata.
    var getEntries: GetCacheEntriesUseCase {
        get async throws {
            try await request.resolveService(GetCacheEntriesUseCase.self)
        }
    }
    
    /// Manual cleanup use case for triggering expired entries cleanup.
    var manualCleanup: ManualCleanupUseCase {
        get async throws {
            try await request.resolveService(ManualCleanupUseCase.self)
        }
    }
    
    /// Get cache health use case for assessing cache performance and health status.
    var getHealth: GetCacheHealthUseCase {
        get async throws {
            try await request.resolveService(GetCacheHealthUseCase.self)
        }
    }
    
    /// Get Redis health use case for testing Redis connectivity and performance.
    var getRedisHealth: GetRedisHealthUseCase {
        get async throws {
            try await request.resolveService(GetRedisHealthUseCase.self)
        }
    }
}