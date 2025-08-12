/// CQRS (Command/Query Responsibility Segregation) protocols for Clean Architecture.
///
/// These protocols extend the UseCase pattern to provide clear separation between
/// operations that modify system state (Commands) and operations that read system 
/// state (Queries). This architectural pattern improves clarity, testability, and
/// enables future optimization opportunities.

/// Base protocol for commands that modify system state.
///
/// Commands represent operations that change the state of the system, such as
/// creating, updating, or deleting entities. They may return success indicators
/// or identifiers of created/modified resources.
///
/// ## Command Design Principles
///
/// - **State Modification**: Commands are the only operations that modify system state
/// - **Idempotency**: Commands should be idempotent when possible to enable safe retries
/// - **Authorization**: Commands typically require stricter authorization than queries
/// - **Audit Logging**: Commands should be logged for audit trails and monitoring
/// - **Validation**: Commands should validate input thoroughly before execution
///
/// ## Implementation Example
/// ```swift
/// struct CreateUserCommand: Command {
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
///     func execute(_ request: Request) async throws -> Response {
///         // Validation, state modification, and response creation
///     }
/// }
/// ```
protocol Command: UseCase {
    // Inherits: func execute(_ request: Request) async throws -> Response
    // Commands may return success indicators or created resource IDs
}

/// Base protocol for queries that read system state without side effects.
///
/// Queries represent read-only operations that retrieve data from the system
/// without modifying any state. They should be side-effect free and safe to
/// execute multiple times.
///
/// ## Query Design Principles
///
/// - **Read-Only**: Queries must never modify system state
/// - **Side-Effect Free**: Safe to execute multiple times with same result
/// - **Performance**: Can be optimized for read performance (caching, indexing)
/// - **Authorization**: May have different authorization rules than commands
/// - **Cacheable**: Queries can be cached since they don't modify state
///
/// ## Implementation Example
/// ```swift
/// struct GetUserQuery: Query {
///     struct Request {
///         let userId: UUID
///     }
///     
///     struct Response {
///         let user: UserProfile
///     }
///     
///     func execute(_ request: Request) async throws -> Response {
///         // Read-only data retrieval
///     }
/// }
/// ```
protocol Query: UseCase {
    // Inherits: func execute(_ request: Request) async throws -> Response
    // Queries return read-only data without modifying system state
}

/// Marker protocol for commands that don't return meaningful data.
///
/// Used for commands that perform actions but don't need to return
/// specific data beyond success confirmation.
///
/// ## Usage Example
/// ```swift
/// struct DeleteUserCommand: VoidCommand {
///     struct Request { let userId: UUID }
///     // Response is Void - no meaningful data returned
/// }
/// ```
protocol VoidCommand: Command where Response == Void {}

/// Marker protocol for queries that return collections of data.
///
/// Used for queries that return lists, arrays, or other collections
/// to enable collection-specific optimizations and type safety.
///
/// ## Usage Example
/// ```swift
/// struct ListUsersQuery: CollectionQuery {
///     struct Request { let limit: Int }
///     struct Response: Collection { 
///         let users: [User]
///         // Collection protocol implementation
///     }
/// }
/// ```
protocol CollectionQuery: Query where Response: Collection {}

/// Marker protocol for commands that create new entities.
///
/// Used for commands that create new resources in the system,
/// typically returning the identifier of the created entity.
protocol CreationCommand: Command {
    associatedtype EntityID
    // Response should contain the ID of the created entity
}

/// Marker protocol for commands that modify existing entities.
///
/// Used for commands that update existing resources in the system,
/// enabling update-specific validation and business logic.
protocol UpdateCommand: Command {
    associatedtype EntityID
    // Request should contain the ID of the entity to update
}