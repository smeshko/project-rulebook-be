import Foundation

public protocol IdentifiableError: Sendable {
    var identifier: String { get }
    var reason: String { get }
}
