import Vapor

struct WaitlistController {

    func subscribe(_ req: Request) async throws -> Waitlist.Subscribe.Response {
        try Waitlist.Subscribe.Request.validate(content: req)
        let subscribeRequest = try req.content.decode(Waitlist.Subscribe.Request.self)

        let repository = req.repositories.waitlist

        // Check for existing entry (idempotent)
        if let existing = try await repository.find(email: subscribeRequest.email) {
            return Waitlist.Subscribe.Response(
                message: "You're already on the waitlist!",
                email: existing.email
            )
        }

        // Create new entry
        let entry = WaitlistEntryModel(email: subscribeRequest.email)
        try await repository.create(entry)

        // Send confirmation email (fire and forget - don't fail on email error)
        Task {
            do {
                try await req.waitlistNotifier.sendConfirmation(to: entry)
            } catch {
                req.logger.error("Failed to send waitlist confirmation email: \(error)")
            }
        }

        return Waitlist.Subscribe.Response(
            message: "Thanks for joining the waitlist!",
            email: entry.email
        )
    }

    func unsubscribe(_ req: Request) async throws -> Waitlist.Unsubscribe.Response {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Missing unsubscribe token")
        }

        let repository = req.repositories.waitlist

        guard let entry = try await repository.find(token: token) else {
            throw Abort(.notFound, reason: "Invalid or expired unsubscribe link")
        }

        try await repository.delete(entry)

        return Waitlist.Unsubscribe.Response(
            message: "You've been removed from the waitlist."
        )
    }

    // MARK: - Admin Endpoints

    func stats(_ req: Request) async throws -> Waitlist.Stats.Response {
        let repository = req.repositories.waitlist

        let total = try await repository.count()
        let notified = try await repository.countNotified()

        return Waitlist.Stats.Response(
            total: total,
            notified: notified,
            pending: total - notified
        )
    }

    func notify(_ req: Request) async throws -> Waitlist.Notify.Response {
        let repository = req.repositories.waitlist
        let entries = try await repository.findUnnotified()

        var sent = 0
        var failed = 0

        for entry in entries {
            do {
                try await req.waitlistNotifier.sendLaunchNotification(to: entry)
                entry.notifiedAt = Date()
                try await repository.update(entry)
                sent += 1
            } catch {
                req.logger.error("Failed to notify \(entry.email): \(error)")
                failed += 1
            }
        }

        return Waitlist.Notify.Response(
            sent: sent,
            failed: failed,
            message: "Notification complete. Sent: \(sent), Failed: \(failed)"
        )
    }
}
