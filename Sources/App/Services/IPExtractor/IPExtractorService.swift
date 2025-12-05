import Vapor

protocol IPExtractorService {
    /// Extracts the real client IP address from the request, checking proxy headers first
    func extractClientIP(from request: Request) -> String
    
    func `for`(_ request: Request) -> IPExtractorService
}

extension Application.Services {
    var ipExtractor: Application.Service<IPExtractorService> {
        .init(application: application)
    }
}

extension Request.Services {
    var ipExtractor: IPExtractorService {
        // Use pre-resolved service from ServiceCache for immediate synchronous access
        request.application.ipExtractorService.for(request)
    }
}