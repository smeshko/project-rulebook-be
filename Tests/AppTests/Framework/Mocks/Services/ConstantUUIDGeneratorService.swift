@testable import App
import Foundation
import Vapor

/// Constant UUID generator service for predictable testing.
///
/// This service implements the UUIDGeneratorService interface but returns
/// predictable UUIDs, making tests deterministic and easier to write.
final class ConstantUUIDGeneratorService: UUIDGeneratorService, @unchecked Sendable {
    private let logger: Logger
    private var currentIndex: Int = 0
    private let uuids: [UUID]
    
    /// Predefined UUIDs for testing
    static let testUUIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    ]
    
    init(app: Application, uuids: [UUID] = testUUIDs) {
        self.logger = app.logger
        self.uuids = uuids
    }
    
    /// Reset the generator to start from the beginning of the UUID list.
    func reset() {
        currentIndex = 0
        logger.info("ConstantUUIDGeneratorService reset to index 0")
    }
    
    /// Set the next UUID index to use.
    func setIndex(_ index: Int) {
        currentIndex = max(0, index) % uuids.count
        logger.info("ConstantUUIDGeneratorService index set to: \(currentIndex)")
    }
    
    /// Get the current index being used.
    var currentUUIDIndex: Int {
        currentIndex
    }
    
    // MARK: - UUIDGeneratorService Implementation
    
    func generate() -> UUID {
        let uuid = uuids[currentIndex]
        currentIndex = (currentIndex + 1) % uuids.count
        
        logger.debug("ConstantUUIDGeneratorService generated: \(uuid)")
        return uuid
    }
    
    func `for`(_ request: Request) -> UUIDGeneratorService {
        return self
    }
}

// MARK: - Service Registration Extension

extension Application.Service.Provider where ServiceType == UUIDGeneratorService {
    /// Provides a constant UUID generator service for testing.
    static var constant: Self {
        .init { app in
            app.services.uuidGenerator.use { ConstantUUIDGeneratorService(app: $0) }
        }
    }
    
    /// Provides a constant UUID generator with custom UUIDs.
    static func constant(uuids: [UUID]) -> Self {
        .init { app in
            app.services.uuidGenerator.use { ConstantUUIDGeneratorService(app: $0, uuids: uuids) }
        }
    }
}