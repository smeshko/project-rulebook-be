/// Core use case protocol for implementing business logic operations.
///
/// Use cases represent single business operations that can be executed independently.
/// They encapsulate business logic and coordinate between domain services and repositories.
///
/// ## Design Principles
///
/// - **Single Responsibility**: Each use case handles one specific business operation
/// - **Testable**: All dependencies are injected, making use cases easy to unit test
/// - **Framework Independent**: No direct dependencies on Vapor or HTTP concerns
/// - **Composable**: Use cases can call other use cases when needed
///
/// ## Implementation Pattern
///
/// ```swift
/// struct CreateUserUseCase: UseCase {
///     struct Request {
///         let email: String
///         let password: String
///     }
///     
///     struct Response {
///         let userId: UUID
///         let createdAt: Date
///     }
///     
///     let userRepository: UserRepository
///     let emailService: EmailService
///     
///     func execute(_ request: Request) async throws -> Response {
///         // Pure business logic here
///     }
/// }
/// ```
protocol UseCase {
    associatedtype Request
    associatedtype Response
    
    /// Executes the use case with the provided request.
    ///
    /// - Parameter request: The input data needed to execute the use case
    /// - Returns: The result of the use case execution
    /// - Throws: Business logic errors or validation failures
    func execute(_ request: Request) async throws -> Response
}