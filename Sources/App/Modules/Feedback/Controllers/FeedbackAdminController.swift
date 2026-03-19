import Vapor

struct FeedbackAdminController {

    func list(_ req: Request) async throws -> Feedback.List.Response {
        // Parse optional status filter
        let statusString: String? = req.query[String.self, at: "status"]
        var statusFilter: FeedbackStatus?

        if let statusString {
            guard let parsed = FeedbackStatus(rawValue: statusString) else {
                throw FeedbackError.invalidFeedbackStatus
            }
            statusFilter = parsed
        }

        // Parse pagination
        let page = req.query[Int.self, at: "page"] ?? 1
        let limit = req.query[Int.self, at: "limit"] ?? 20

        let result = try await req.repositories.feedback.findPaginated(
            status: statusFilter,
            page: page,
            limit: limit
        )

        let items = try result.items.map { try Feedback.Detail.Response(from: $0) }

        let clientIP = req.headers.first(name: "X-Forwarded-For") ?? req.remoteAddress?.description ?? "unknown"
        req.logger.info("Admin listed feedback", metadata: [
            "clientIP": .string(clientIP),
            "statusFilter": .string(statusString ?? "all"),
            "page": .string("\(page)"),
            "limit": .string("\(limit)"),
            "totalResults": .string("\(result.total)")
        ])

        return Feedback.List.Response(
            items: items,
            total: result.total,
            page: page,
            limit: limit
        )
    }

    func updateStatus(_ req: Request) async throws -> Feedback.Detail.Response {
        guard let feedbackId = req.parameters.get("feedbackId", as: UUID.self) else {
            throw FeedbackError.feedbackNotFound
        }

        let input = try req.content.decode(Feedback.UpdateStatus.Request.self)

        // Validate status
        guard let newStatus = FeedbackStatus(rawValue: input.status) else {
            throw FeedbackError.invalidFeedbackStatus
        }

        // Find feedback
        guard let model = try await req.repositories.feedback.find(id: feedbackId) else {
            throw FeedbackError.feedbackNotFound
        }

        let oldStatus = model.status
        model.status = newStatus
        try await req.repositories.feedback.update(model)

        let clientIP = req.headers.first(name: "X-Forwarded-For") ?? req.remoteAddress?.description ?? "unknown"
        req.logger.info("Admin updated feedback status", metadata: [
            "clientIP": .string(clientIP),
            "feedbackId": .string(feedbackId.uuidString),
            "oldStatus": .string(oldStatus.rawValue),
            "newStatus": .string(newStatus.rawValue)
        ])

        return try Feedback.Detail.Response(from: model)
    }
}
