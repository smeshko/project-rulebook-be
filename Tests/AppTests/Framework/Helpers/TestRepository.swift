@testable import App
import Vapor

protocol TestRepository: AnyObject {
    /// Reset the repository to its initial state for testing.
    func reset() async
}

extension TestRepository where Self: RequestService {
    func `for`(_ req: Request) -> Self {
        return self
    }
}
