import Vapor

struct WaitlistNotifier {
    let application: Application

    func sendConfirmation(to entry: WaitlistEntryModel) async throws {
        let baseURL = try application.configuration.security.baseURL

        let content = BrevoMail(
            sender: .init(
                name: "Sender",
                email: "noreply@sender.com"
            ),
            to: [.init(
                name: entry.email,
                email: entry.email
            )],
            subject: "You're on the waitlist!",
            htmlContent: Templates.waitlistConfirmation(
                unsubscribeToken: entry.unsubscribeToken,
                baseURL: baseURL
            )
        )

        try await application.serviceCache.emailService.send(content)
    }

    func sendLaunchNotification(to entry: WaitlistEntryModel) async throws {
        let baseURL = try application.configuration.security.baseURL

        let content = BrevoMail(
            sender: .init(
                name: "Sender",
                email: "noreply@sender.com"
            ),
            to: [.init(
                name: entry.email,
                email: entry.email
            )],
            subject: "We're live! The app is ready",
            htmlContent: Templates.waitlistLaunchNotification(
                unsubscribeToken: entry.unsubscribeToken,
                baseURL: baseURL
            )
        )

        try await application.serviceCache.emailService.send(content)
    }
}

extension Application {
    var waitlistNotifier: WaitlistNotifier {
        .init(application: self)
    }
}

extension Request {
    var waitlistNotifier: WaitlistNotifier {
        .init(application: application)
    }
}
