import Vapor

extension Application {
    public struct Repositories {
        public let application: Application
    }

    public var repositories: Repositories {
        .init(application: self)
    }
}
