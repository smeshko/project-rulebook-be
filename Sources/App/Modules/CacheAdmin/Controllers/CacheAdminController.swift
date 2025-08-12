import Vapor

/// Admin controller for managing AI response cache
struct CacheAdminController {
    
    // MARK: - Cache Statistics Endpoint
    
    /// GET /api/admin/cache/stats
    /// Returns detailed cache statistics and performance metrics
    func getCacheStatistics(_ req: Request) async throws -> CacheAdmin.Statistics.Response {
        let useCase = try await req.useCases.cacheAdmin.getStats
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        
        return try await useCase.execute(
            GetCacheStatsUseCase.Request(clientIP: clientIP)
        )
    }
    
    // MARK: - Clear Cache Endpoint
    
    /// DELETE /api/admin/cache
    /// Clears all entries from the cache
    func clearCache(_ req: Request) async throws -> CacheAdmin.Clear.Response {
        let useCase = try await req.useCases.cacheAdmin.clearCache
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        
        return try await useCase.execute(
            ClearCacheUseCase.Request(clientIP: clientIP)
        )
    }
    
    // MARK: - Cache Entries Endpoint
    
    /// GET /api/admin/cache/entries
    /// Lists all cached entries with metadata (paginated for large caches)
    func getCacheEntries(_ req: Request) async throws -> CacheAdmin.Entries.Response {
        let useCase = try await req.useCases.cacheAdmin.getEntries
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        
        return try await useCase.execute(
            GetCacheEntriesUseCase.Request(clientIP: clientIP)
        )
    }
    
    // MARK: - Manual Cleanup Endpoint
    
    /// POST /api/admin/cache/cleanup
    /// Manually triggers cleanup of expired entries
    func manualCleanup(_ req: Request) async throws -> CacheAdmin.Cleanup.Response {
        let useCase = try await req.useCases.cacheAdmin.manualCleanup
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        
        return try await useCase.execute(
            ManualCleanupUseCase.Request(clientIP: clientIP)
        )
    }
    
    // MARK: - Cache Health Endpoint
    
    /// GET /api/admin/cache/health
    /// Returns cache health status and performance metrics
    func getCacheHealth(_ req: Request) async throws -> CacheAdmin.Health.Response {
        let useCase = try await req.useCases.cacheAdmin.getHealth
        let clientIP = req.services.ipExtractor.extractClientIP(from: req)
        
        return try await useCase.execute(
            GetCacheHealthUseCase.Request(clientIP: clientIP)
        )
    }
    
}


