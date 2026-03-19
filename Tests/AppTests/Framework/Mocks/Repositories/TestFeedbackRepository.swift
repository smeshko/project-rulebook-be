@testable import App
import Vapor

actor TestFeedbackRepository: FeedbackRepository, TestRepository {
    var feedbacks: [FeedbackModel]

    init(feedbacks: [FeedbackModel] = []) {
        self.feedbacks = feedbacks
    }

    typealias Model = FeedbackModel

    func find(id: UUID) async throws -> FeedbackModel? {
        feedbacks.first { $0.id == id }
    }

    func create(_ model: FeedbackModel) async throws {
        model.id = model.id ?? UUID()
        if model.createdAt == nil {
            model.createdAt = Date()
        }
        feedbacks.append(model)
    }

    func all() async throws -> [FeedbackModel] {
        feedbacks.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func findByStatus(_ status: FeedbackStatus) async throws -> [FeedbackModel] {
        feedbacks
            .filter { $0.status == status }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func findPaginated(status: FeedbackStatus?, page: Int, limit: Int) async throws -> (items: [FeedbackModel], total: Int) {
        let safePage = max(1, page)
        let safeLimit = max(1, min(limit, 100))
        var filtered = feedbacks
        if let status {
            filtered = filtered.filter { $0.status == status }
        }
        let total = filtered.count
        let sorted = filtered.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        let offset = (safePage - 1) * safeLimit
        let items = Array(sorted.dropFirst(offset).prefix(safeLimit))
        return (items: items, total: total)
    }

    func update(_ model: FeedbackModel) async throws {
        guard let id = model.id,
              let index = feedbacks.firstIndex(where: { $0.id == id }) else {
            throw Abort(.notFound)
        }
        feedbacks[index] = model
    }

    func count(status: FeedbackStatus?) async throws -> Int {
        if let status {
            return feedbacks.filter { $0.status == status }.count
        }
        return feedbacks.count
    }

    func delete(id: UUID) async throws {
        feedbacks.removeAll { $0.id == id }
    }

    func count() async throws -> Int {
        feedbacks.count
    }

    func reset() async {
        feedbacks.removeAll()
    }

    nonisolated func `for`(_ req: Request) -> TestFeedbackRepository {
        self
    }
}
