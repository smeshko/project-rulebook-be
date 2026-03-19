import Foundation
import SQLKit
import Vapor

struct HealthController {

    func check(_ req: Request) async throws -> Response {
        let databaseStatus = await checkDatabase(req)
        let redisStatus = await checkRedis(req)

        let allHealthy = databaseStatus == "ok" && redisStatus == "ok"
        let status = allHealthy ? "healthy" : "unhealthy"
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let body = Health.Check.Response(
            status: status,
            timestamp: timestamp,
            checks: Health.Check.Checks(
                database: databaseStatus,
                redis: redisStatus
            )
        )

        let httpStatus: HTTPStatus = allHealthy ? .ok : .serviceUnavailable

        if !allHealthy {
            req.logger.warning("Health check unhealthy", metadata: [
                "database": .string(databaseStatus),
                "redis": .string(redisStatus)
            ])
        }

        let response = Response(status: httpStatus)
        try response.content.encode(body)
        return response
    }

    // MARK: - Private Health Probes

    private func checkDatabase(_ req: Request) async -> String {
        do {
            guard let sqlDB = req.db as? any SQLDatabase else {
                req.logger.warning("Database health check skipped: req.db is not an SQLDatabase")
                return "error"
            }
            _ = try await sqlDB.raw("SELECT 1").first()
            return "ok"
        } catch {
            req.logger.error("Database health check failed", metadata: [
                "error": .string(String(describing: error))
            ])
            return "error"
        }
    }

    private func checkRedis(_ req: Request) async -> String {
        do {
            let healthKey = "health:ping:\(UUID().uuidString)"
            try await req.services.cache.set(healthKey, value: "pong", ttl: 5.0)
            let result: String? = try await req.services.cache.get(healthKey, as: String.self)
            try? await req.services.cache.delete(healthKey)

            guard result == "pong" else {
                return "error"
            }
            return "ok"
        } catch {
            req.logger.error("Redis health check failed", metadata: [
                "error": .string(String(describing: error))
            ])
            return "error"
        }
    }
}
