import Vapor

enum Waitlist {
    enum Subscribe {
        struct Request: Content, Validatable {
            let email: String

            static func validations(_ validations: inout Validations) {
                validations.add("email", as: String.self, is: .email)
            }
        }

        struct Response: Content {
            let message: String
            let email: String
        }
    }

    enum Unsubscribe {
        struct Response: Content {
            let message: String
        }
    }

    enum Stats {
        struct Response: Content {
            let total: Int
            let notified: Int
            let pending: Int
        }
    }

    enum Notify {
        struct Response: Content {
            let sent: Int
            let failed: Int
            let message: String
        }
    }
}
