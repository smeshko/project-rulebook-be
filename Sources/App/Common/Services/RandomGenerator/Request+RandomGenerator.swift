import Vapor

public extension Request {
    var random: RandomGenerator {
        self.application.random
    }
}
