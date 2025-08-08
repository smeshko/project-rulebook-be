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
        self.request.application.services.ipExtractor.service.for(request)
    }
}