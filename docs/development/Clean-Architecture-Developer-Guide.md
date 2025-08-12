# Clean Architecture Developer Guide

## Overview

This guide provides practical instructions for developers working with the Clean Architecture implementation in Project Rulebook. It covers how to create new use cases, implement domain services, follow testing patterns, and maintain architectural consistency.

## Table of Contents

- [Quick Reference](#quick-reference)
- [Creating New Use Cases](#creating-new-use-cases)  
- [Implementing Domain Services](#implementing-domain-services)
- [Controller Implementation](#controller-implementation)
- [Service Registration](#service-registration)
- [Testing Patterns](#testing-patterns)
- [Error Handling](#error-handling)
- [Performance Guidelines](#performance-guidelines)
- [Code Examples](#code-examples)

## Quick Reference

### Architecture Layers
1. **Controllers** - HTTP request/response handling
2. **Use Cases** - Business logic orchestration  
3. **Domain Services** - Complex business logic
4. **Infrastructure** - External services and repositories

### CQRS Patterns
- **Commands** - Write operations that modify state
- **Queries** - Read operations without side effects
- **VoidCommands** - Commands that don't return data
- **CollectionQueries** - Queries that return collections

### Service Resolution
```swift
// Request-level service access (cached)
request.services.userRepository

// Application-level service resolution
try await app.resolveRequired(UserService.self)
```

## Creating New Use Cases

### Use Case Template

```swift
import Foundation
import Vapor

/// [Brief description of what this use case does]
///
/// This use case handles [specific business operation] including:
/// - [Key responsibility 1]
/// - [Key responsibility 2] 
/// - [Key responsibility 3]
struct [UseCaseName]: [Command/Query] {
    
    /// Request parameters for [operation] operation.
    struct Request {
        let param1: Type
        let param2: Type
        
        init(param1: Type, param2: Type) {
            self.param1 = param1
            self.param2 = param2
        }
    }
    
    /// Response from [operation] operation.
    struct Response {
        let result1: Type
        let result2: Type
        let timestamp: Date
    }
    
    // Dependencies (injected via constructor)
    let repository: any RepositoryProtocol
    let service: ServiceProtocol
    
    /// Executes the [operation] use case.
    ///
    /// [Detailed description of business logic]
    ///
    /// - Parameter request: [Description of request parameters]
    /// - Returns: [Description of response data]
    /// - Throws: [List of possible errors]
    func execute(_ request: Request) async throws -> Response {
        // Step 1: Validation and preparation
        
        // Step 2: Core business logic
        
        // Step 3: Return structured response
    }
}
```

### Command Example: Creating a Game Review

```swift
import Foundation
import Vapor

/// Use case for creating game reviews.
///
/// Handles the business logic for game review creation including:
/// - Input validation and sanitization
/// - Duplicate review checking
/// - Review content moderation
/// - Notification triggers
struct CreateGameReviewUseCase: CreationCommand {
    typealias EntityID = UUID
    
    struct Request {
        let gameTitle: String
        let rating: Int
        let comment: String
        let userId: UUID
        
        init(gameTitle: String, rating: Int, comment: String, userId: UUID) {
            self.gameTitle = gameTitle
            self.rating = rating
            self.comment = comment
            self.userId = userId
        }
    }
    
    struct Response {
        let reviewId: UUID
        let gameTitle: String
        let rating: Int
        let createdAt: Date
        let moderationStatus: String
    }
    
    // Dependencies
    let reviewRepository: any GameReviewRepository
    let moderationService: ModerationService
    let notificationService: NotificationService
    
    func execute(_ request: Request) async throws -> Response {
        // 1. Validate rating range
        guard (1...5).contains(request.rating) else {
            throw ValidationError.invalidRating
        }
        
        // 2. Check for duplicate review
        let existingReview = try await reviewRepository.find(
            gameTitle: request.gameTitle,
            userId: request.userId
        )
        guard existingReview == nil else {
            throw GameReviewError.duplicateReview
        }
        
        // 3. Moderate review content
        let moderationResult = try await moderationService.moderate(request.comment)
        
        // 4. Create review
        let review = GameReviewModel(
            gameTitle: request.gameTitle,
            rating: request.rating,
            comment: request.comment,
            userId: request.userId,
            moderationStatus: moderationResult.status
        )
        
        let savedReview = try await reviewRepository.create(review)
        
        // 5. Send notifications if approved
        if moderationResult.approved {
            try await notificationService.notifyNewReview(savedReview)
        }
        
        return Response(
            reviewId: try savedReview.requireID(),
            gameTitle: savedReview.gameTitle,
            rating: savedReview.rating,
            createdAt: savedReview.createdAt ?? Date.now,
            moderationStatus: moderationResult.status
        )
    }
}
```

### Query Example: Getting Game Reviews

```swift
import Foundation
import Vapor

/// Use case for retrieving game reviews.
///
/// Handles read-only access to game review data including:
/// - Filtering and pagination
/// - Review aggregation statistics
/// - User permission checking
struct GetGameReviewsUseCase: CollectionQuery {
    
    struct Request {
        let gameTitle: String?
        let userId: UUID?
        let limit: Int
        let offset: Int
        let includeModerated: Bool
        
        init(
            gameTitle: String? = nil,
            userId: UUID? = nil,
            limit: Int = 20,
            offset: Int = 0,
            includeModerated: Bool = false
        ) {
            self.gameTitle = gameTitle
            self.userId = userId
            self.limit = min(limit, 100) // Cap at 100
            self.offset = max(offset, 0)
            self.includeModerated = includeModerated
        }
    }
    
    struct Response: Collection {
        let reviews: [GameReviewModel]
        let totalCount: Int
        let averageRating: Double?
        let hasMore: Bool
        
        // Collection conformance
        var startIndex: Int { reviews.startIndex }
        var endIndex: Int { reviews.endIndex }
        func index(after i: Int) -> Int { reviews.index(after: i) }
        subscript(position: Int) -> GameReviewModel { reviews[position] }
    }
    
    // Dependencies
    let reviewRepository: any GameReviewRepository
    
    func execute(_ request: Request) async throws -> Response {
        // 1. Build query filters
        var filters: [GameReviewFilter] = []
        
        if let gameTitle = request.gameTitle {
            filters.append(.gameTitle(gameTitle))
        }
        
        if let userId = request.userId {
            filters.append(.userId(userId))
        }
        
        if !request.includeModerated {
            filters.append(.approved)
        }
        
        // 2. Execute paginated query
        let reviews = try await reviewRepository.findAll(
            filters: filters,
            limit: request.limit,
            offset: request.offset
        )
        
        // 3. Get total count for pagination
        let totalCount = try await reviewRepository.count(filters: filters)
        
        // 4. Calculate average rating if filtering by game
        let averageRating: Double?
        if request.gameTitle != nil {
            averageRating = try await reviewRepository.averageRating(
                gameTitle: request.gameTitle!,
                includeModerated: request.includeModerated
            )
        } else {
            averageRating = nil
        }
        
        return Response(
            reviews: reviews,
            totalCount: totalCount,
            averageRating: averageRating,
            hasMore: totalCount > request.offset + reviews.count
        )
    }
}
```

## Implementing Domain Services

Domain services handle complex business logic that spans multiple entities or involves external integrations.

### Domain Service Template

```swift
import Foundation
import Vapor

/// Domain service for [business domain].
///
/// This service encapsulates [complex business logic description].
/// It coordinates [list of responsibilities].
protocol [ServiceName]: Sendable {
    /// [Method description]
    ///
    /// - Parameters:
    ///   - param1: [Description]
    ///   - request: Vapor request for accessing services
    /// - Returns: [Return description]
    /// - Throws: [Error types]
    func [methodName](
        param1: Type,
        request: Request
    ) async throws -> ReturnType
}

/// Production implementation of [ServiceName].
final class Default[ServiceName]: [ServiceName] {
    
    init() {}
    
    func [methodName](
        param1: Type,
        request: Request
    ) async throws -> ReturnType {
        // Implementation using request.services for dependencies
    }
}
```

### Example: Game Recommendation Service

```swift
import Foundation
import Vapor

/// Domain service for generating personalized game recommendations.
///
/// This service encapsulates complex recommendation logic including:
/// - User preference analysis
/// - Similarity algorithms
/// - Inventory filtering
/// - Performance optimization
protocol GameRecommendationService: Sendable {
    /// Generates personalized game recommendations for a user.
    ///
    /// - Parameters:
    ///   - userId: User ID for personalization
    ///   - count: Number of recommendations to generate
    ///   - request: Vapor request for accessing services
    /// - Returns: Ordered list of game recommendations
    /// - Throws: UserError if user not found, AIError for recommendation failures
    func generateRecommendations(
        for userId: UUID,
        count: Int,
        request: Request
    ) async throws -> [GameRecommendation]
}

/// Production implementation of GameRecommendationService.
final class DefaultGameRecommendationService: GameRecommendationService {
    
    init() {}
    
    func generateRecommendations(
        for userId: UUID,
        count: Int,
        request: Request
    ) async throws -> [GameRecommendation] {
        
        request.logger.info("Generating game recommendations", metadata: [
            "user_id": .string(userId.uuidString),
            "count": .string("\(count)")
        ])
        
        // 1. Get user preferences and history
        let user = try await request.services.userRepository.find(id: userId)
        guard let user = user else {
            throw UserError.userNotFound(userId)
        }
        
        let preferences = try await request.services.userPreferencesRepository
            .getPreferences(for: userId)
        
        let reviewHistory = try await request.services.gameReviewRepository
            .getUserReviews(userId: userId, limit: 50)
        
        // 2. Check cache for recent recommendations
        let cacheKey = request.services.cacheKeyGenerator
            .generateRecommendationKey(for: userId)
        
        if let cached = await request.services.aiCache.get(key: cacheKey),
           let recommendations = try? JSONDecoder()
               .decode([GameRecommendation].self, from: Data(cached.utf8)) {
            
            request.logger.debug("Using cached recommendations", metadata: [
                "user_id": .string(userId.uuidString),
                "cache_key": .string(cacheKey)
            ])
            
            return Array(recommendations.prefix(count))
        }
        
        // 3. Generate AI-powered recommendations
        let recommendationPrompt = buildRecommendationPrompt(
            preferences: preferences,
            reviewHistory: reviewHistory
        )
        
        let aiResponse = try await request.services.llm.generateOptimized(
            input: recommendationPrompt,
            model: "gpt-4o-mini",
            temperature: 0.3,
            maxTokens: 800,
            useJSONMode: true
        )
        
        // 4. Parse and validate AI recommendations
        let validationService = try await request.resolveService(AIResponseValidationService.self)
        let validatedResponse = try validationService.validateRecommendationResponse(
            aiResponse,
            userId: userId.uuidString,
            clientIP: request.services.ipExtractor.extractClientIP(from: request),
            logger: request.logger
        )
        
        let recommendations = try JSONDecoder()
            .decode([GameRecommendation].self, from: Data(validatedResponse.utf8))
        
        // 5. Filter by availability and user preferences
        let filteredRecommendations = try await filterRecommendations(
            recommendations,
            user: user,
            request: request
        )
        
        // 6. Cache successful recommendations
        let cacheData = try JSONEncoder().encode(filteredRecommendations)
        await request.services.aiCache.set(
            key: cacheKey,
            value: String(data: cacheData, encoding: .utf8) ?? "",
            ttl: 3600 // 1 hour
        )
        
        request.logger.info("Generated recommendations successfully", metadata: [
            "user_id": .string(userId.uuidString),
            "recommendations_count": .string("\(filteredRecommendations.count)")
        ])
        
        return Array(filteredRecommendations.prefix(count))
    }
    
    private func buildRecommendationPrompt(
        preferences: UserPreferences,
        reviewHistory: [GameReviewModel]
    ) -> String {
        // Build detailed prompt based on user data
        return """
        Generate game recommendations based on user preferences and history.
        
        User Preferences:
        - Favorite genres: \(preferences.favoriteGenres.joined(separator: ", "))
        - Player count preference: \(preferences.playerCountRange)
        - Complexity preference: \(preferences.complexityLevel)
        
        Recent highly-rated games:
        \(reviewHistory.filter { $0.rating >= 4 }.prefix(5)
            .map { "- \($0.gameTitle) (rated \($0.rating)/5)" }
            .joined(separator: "\n"))
        
        Return JSON array with this structure:
        [
          {
            "title": "Game Name",
            "genres": ["Genre1", "Genre2"],
            "playerCount": "2-4 players",
            "complexity": "Medium",
            "reasoning": "Why this game fits user preferences",
            "confidence": 85
          }
        ]
        """
    }
    
    private func filterRecommendations(
        _ recommendations: [GameRecommendation],
        user: UserAccountModel,
        request: Request
    ) async throws -> [GameRecommendation] {
        // Filter recommendations based on availability, user history, etc.
        return recommendations.filter { recommendation in
            // Add filtering logic here
            return true
        }
    }
}
```

## Controller Implementation

Controllers should be thin layers that handle only HTTP concerns:

### Controller Template

```swift
import Vapor

/// HTTP controller for [domain] operations.
///
/// This controller provides REST endpoints for [domain] management
/// and delegates all business logic to use cases.
struct [DomainName]Controller: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "domain")
        
        // Public endpoints
        api.get("resource", use: getResource)
        
        // Authenticated endpoints
        let authenticated = api.grouped(UserCredentialsAuthenticator())
        authenticated.post("resource", use: createResource)
        authenticated.patch("resource", ":id", use: updateResource)
        
        // Admin endpoints
        let admin = authenticated.grouped(EnsureAdminUserMiddleware())
        admin.delete("resource", ":id", use: deleteResource)
    }
    
    /// GET /api/domain/resource
    func getResource(_ request: Request) async throws -> Response {
        // 1. Parse and validate HTTP input
        let queryParams = try request.query.decode(GetResourceQuery.self)
        
        // 2. Execute use case
        let useCase = try await request.resolveRequired(GetResourceUseCase.self)
        let result = try await useCase.execute(.init(
            param1: queryParams.param1,
            param2: queryParams.param2
        ))
        
        // 3. Format HTTP response
        return ResourceListResponse(
            resources: result.resources.map(ResourceResponse.init),
            pagination: PaginationResponse(
                total: result.totalCount,
                hasMore: result.hasMore
            )
        )
    }
    
    /// POST /api/domain/resource
    func createResource(_ request: Request) async throws -> Response {
        // 1. Parse and validate HTTP input
        let input = try request.content.decode(CreateResourceRequest.self)
        
        // 2. Execute use case
        let useCase = try await request.resolveRequired(CreateResourceUseCase.self)
        let result = try await useCase.execute(.init(
            name: input.name,
            description: input.description,
            userId: try request.user.requireID()
        ))
        
        // 3. Format HTTP response with 201 Created
        return ResourceResponse(from: result)
            .encodeResponse(status: .created, for: request)
    }
}
```

### Real Example: Game Review Controller

```swift
import Vapor

/// HTTP controller for game review operations.
struct GameReviewController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let reviews = routes.grouped("api", "reviews")
        
        // Public endpoints
        reviews.get(use: getReviews)
        reviews.get("game", ":gameTitle", use: getGameReviews)
        
        // Authenticated endpoints
        let authenticated = reviews.grouped(UserCredentialsAuthenticator())
        authenticated.post(use: createReview)
        authenticated.patch(":id", use: updateReview)
        authenticated.delete(":id", use: deleteReview)
    }
    
    /// GET /api/reviews
    func getReviews(_ request: Request) async throws -> GameReviewListResponse {
        let query = try request.query.decode(GetReviewsQuery.self)
        
        let useCase = try await request.resolveRequired(GetGameReviewsUseCase.self)
        let result = try await useCase.execute(.init(
            gameTitle: query.gameTitle,
            limit: query.limit ?? 20,
            offset: query.offset ?? 0,
            includeModerated: request.user?.isAdmin == true
        ))
        
        return GameReviewListResponse(
            reviews: result.reviews.map(GameReviewResponse.init),
            totalCount: result.totalCount,
            averageRating: result.averageRating,
            pagination: PaginationResponse(
                limit: query.limit ?? 20,
                offset: query.offset ?? 0,
                hasMore: result.hasMore
            )
        )
    }
    
    /// POST /api/reviews
    func createReview(_ request: Request) async throws -> Response {
        let input = try request.content.decode(CreateGameReviewRequest.self)
        
        let useCase = try await request.resolveRequired(CreateGameReviewUseCase.self)
        let result = try await useCase.execute(.init(
            gameTitle: input.gameTitle,
            rating: input.rating,
            comment: input.comment,
            userId: try request.user.requireID()
        ))
        
        return GameReviewResponse(
            id: result.reviewId,
            gameTitle: result.gameTitle,
            rating: result.rating,
            comment: input.comment,
            moderationStatus: result.moderationStatus,
            createdAt: result.createdAt
        ).encodeResponse(status: .created, for: request)
    }
}
```

## Service Registration

### Use Case Registration

```swift
extension Application.ServiceRegistry {
    func registerGameReviewUseCases() {
        // Commands
        register(CreateGameReviewUseCase.self) { app in
            return CreateGameReviewUseCase(
                reviewRepository: try await app.resolveRequired(GameReviewRepository.self),
                moderationService: try await app.resolveRequired(ModerationService.self),
                notificationService: try await app.resolveRequired(NotificationService.self)
            )
        }
        
        // Queries
        register(GetGameReviewsUseCase.self) { app in
            return GetGameReviewsUseCase(
                reviewRepository: try await app.resolveRequired(GameReviewRepository.self)
            )
        }
    }
}
```

### Domain Service Registration

```swift
extension Application.ServiceRegistry {
    func registerGameDomainServices() {
        register(GameRecommendationService.self) { app in
            return DefaultGameRecommendationService()
        }
        
        register(ModerationService.self) { app in
            return AIContentModerationService(
                llmService: try await app.resolveRequired(LLMService.self),
                logger: app.logger
            )
        }
    }
}
```

## Testing Patterns

### Use Case Testing

```swift
import XCTest
@testable import App

final class CreateGameReviewUseCaseTests: UnitTestCase {
    var useCase: CreateGameReviewUseCase!
    var mockReviewRepository: TestGameReviewRepository!
    var mockModerationService: MockModerationService!
    var mockNotificationService: MockNotificationService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockReviewRepository = TestGameReviewRepository()
        mockModerationService = MockModerationService()
        mockNotificationService = MockNotificationService()
        
        useCase = CreateGameReviewUseCase(
            reviewRepository: mockReviewRepository,
            moderationService: mockModerationService,
            notificationService: mockNotificationService
        )
    }
    
    func testSuccessfulReviewCreation() async throws {
        // Given
        let user = try testWorld.users.testUser()
        mockModerationService.willReturnApproved()
        
        let request = CreateGameReviewUseCase.Request(
            gameTitle: "Monopoly",
            rating: 5,
            comment: "Great game!",
            userId: user.requireID()
        )
        
        // When
        let result = try await useCase.execute(request)
        
        // Then
        XCTAssertEqual(result.gameTitle, "Monopoly")
        XCTAssertEqual(result.rating, 5)
        XCTAssertEqual(result.moderationStatus, "approved")
        
        // Verify repository interaction
        XCTAssertEqual(mockReviewRepository.createdReviews.count, 1)
        
        // Verify moderation was called
        XCTAssertEqual(mockModerationService.moderationCalls.count, 1)
        XCTAssertEqual(mockModerationService.moderationCalls.first, "Great game!")
        
        // Verify notification was sent
        XCTAssertEqual(mockNotificationService.notificationsSent.count, 1)
    }
    
    func testDuplicateReviewRejection() async throws {
        // Given
        let user = try testWorld.users.testUser()
        mockReviewRepository.existingReviews["Monopoly:\(user.id?.uuidString ?? "")"] = 
            GameReviewModel(gameTitle: "Monopoly", rating: 4, comment: "Old review", userId: user.requireID())
        
        let request = CreateGameReviewUseCase.Request(
            gameTitle: "Monopoly",
            rating: 5,
            comment: "Great game!",
            userId: user.requireID()
        )
        
        // When/Then
        await XCTAssertThrowsError(try await useCase.execute(request)) { error in
            XCTAssertEqual(error as? GameReviewError, .duplicateReview)
        }
        
        // Verify no review was created
        XCTAssertEqual(mockReviewRepository.createdReviews.count, 0)
    }
}
```

### Integration Testing

```swift
final class GameReviewIntegrationTests: IntegrationTestCase {
    
    func testCreateReviewEndpoint() async throws {
        // Given
        let user = try await testWorld.users.createTestUser()
        let token = try testWorld.auth.generateToken(for: user)
        
        let requestBody = CreateGameReviewRequest(
            gameTitle: "Monopoly",
            rating: 5,
            comment: "Excellent game for family night!"
        )
        
        // When
        try await app.test(.POST, "api/reviews", headers: [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]) { request in
            try request.content.encode(requestBody)
        } afterResponse: { response in
            // Then
            XCTAssertEqual(response.status, .created)
            
            let reviewResponse = try response.content.decode(GameReviewResponse.self)
            XCTAssertEqual(reviewResponse.gameTitle, "Monopoly")
            XCTAssertEqual(reviewResponse.rating, 5)
            XCTAssertEqual(reviewResponse.comment, "Excellent game for family night!")
            XCTAssertNotNil(reviewResponse.id)
            XCTAssertNotNil(reviewResponse.createdAt)
        }
    }
    
    func testGetReviewsWithFiltering() async throws {
        // Given
        try await testWorld.reviews.createTestReviews([
            ("Monopoly", 5, "Great!"),
            ("Scrabble", 4, "Good game"),
            ("Monopoly", 3, "Okay")
        ])
        
        // When
        try await app.test(.GET, "api/reviews?gameTitle=Monopoly") { response in
            // Then
            XCTAssertEqual(response.status, .ok)
            
            let reviewList = try response.content.decode(GameReviewListResponse.self)
            XCTAssertEqual(reviewList.reviews.count, 2)
            XCTAssertTrue(reviewList.reviews.allSatisfy { $0.gameTitle == "Monopoly" })
            XCTAssertEqual(reviewList.averageRating, 4.0)
        }
    }
}
```

## Error Handling

### Domain Errors

```swift
/// Game review specific errors
enum GameReviewError: IdentifiableError {
    case duplicateReview
    case reviewNotFound(UUID)
    case invalidRating(Int)
    case commentTooLong
    case moderationFailed
    case notAuthorized(UUID)
}

extension GameReviewError: AbortError {
    var status: HTTPResponseStatus {
        switch self {
        case .duplicateReview:
            return .conflict
        case .reviewNotFound:
            return .notFound
        case .invalidRating, .commentTooLong:
            return .badRequest
        case .moderationFailed:
            return .internalServerError
        case .notAuthorized:
            return .forbidden
        }
    }
    
    var reason: String {
        switch self {
        case .duplicateReview:
            return "You have already reviewed this game"
        case .reviewNotFound(let id):
            return "Review with ID \(id) not found"
        case .invalidRating(let rating):
            return "Rating must be between 1 and 5, got \(rating)"
        case .commentTooLong:
            return "Review comment must be 500 characters or less"
        case .moderationFailed:
            return "Failed to moderate review content"
        case .notAuthorized:
            return "You are not authorized to perform this action"
        }
    }
}
```

### Use Case Error Handling

```swift
func execute(_ request: Request) async throws -> Response {
    do {
        // Business logic here
        return response
    } catch let validationError as ValidationError {
        // Log validation failures
        logger.warning("Validation failed", metadata: [
            "error": .string(validationError.description),
            "request": .string(String(describing: request))
        ])
        throw validationError
    } catch let repositoryError as RepositoryError {
        // Log repository failures
        logger.error("Repository operation failed", metadata: [
            "error": .string(repositoryError.description),
            "operation": .string("create_review")
        ])
        throw GameReviewError.moderationFailed
    } catch {
        // Log unexpected errors
        logger.error("Unexpected error in use case", metadata: [
            "error": .string(error.localizedDescription),
            "use_case": .string("CreateGameReviewUseCase")
        ])
        throw error
    }
}
```

## Performance Guidelines

### Use Case Performance

- Keep use cases focused and single-purpose
- Minimize database queries through efficient repository design
- Use async/await for I/O operations
- Avoid complex computations in use cases

### Service Resolution Performance

```swift
// ✅ Good: Use request.services for cached resolution
let result = try await request.services.someService.performOperation()

// ❌ Avoid: Direct app resolution in hot paths
let service = try await request.application.resolveRequired(SomeService.self)
```

### Caching in Domain Services

```swift
func expensiveOperation(request: Request) async throws -> Result {
    // Check cache first
    let cacheKey = generateCacheKey()
    if let cached = await request.services.cache.get(key: cacheKey) {
        return cached
    }
    
    // Perform expensive operation
    let result = try await performExpensiveOperation()
    
    // Cache result
    await request.services.cache.set(key: cacheKey, value: result, ttl: 3600)
    
    return result
}
```

## Code Examples

### Complete Feature Implementation

Here's a complete example of adding a new "Game Collections" feature:

#### 1. Use Cases

```swift
// CreateGameCollectionUseCase.swift
struct CreateGameCollectionUseCase: CreationCommand {
    typealias EntityID = UUID
    
    struct Request {
        let name: String
        let description: String
        let isPublic: Bool
        let userId: UUID
    }
    
    struct Response {
        let collectionId: UUID
        let name: String
        let createdAt: Date
    }
    
    let collectionRepository: any GameCollectionRepository
    
    func execute(_ request: Request) async throws -> Response {
        let collection = GameCollectionModel(
            name: request.name,
            description: request.description,
            isPublic: request.isPublic,
            userId: request.userId
        )
        
        let saved = try await collectionRepository.create(collection)
        
        return Response(
            collectionId: try saved.requireID(),
            name: saved.name,
            createdAt: saved.createdAt ?? Date.now
        )
    }
}

// GetUserCollectionsUseCase.swift
struct GetUserCollectionsUseCase: CollectionQuery {
    struct Request {
        let userId: UUID
        let includePrivate: Bool
    }
    
    struct Response: Collection {
        let collections: [GameCollectionModel]
        // Collection conformance implementation
    }
    
    let collectionRepository: any GameCollectionRepository
    
    func execute(_ request: Request) async throws -> Response {
        let collections = try await collectionRepository.findByUser(
            userId: request.userId,
            includePrivate: request.includePrivate
        )
        
        return Response(collections: collections)
    }
}
```

#### 2. Controller

```swift
// GameCollectionController.swift
struct GameCollectionController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let collections = routes.grouped("api", "collections")
        
        let authenticated = collections.grouped(UserCredentialsAuthenticator())
        authenticated.get("mine", use: getMyCollections)
        authenticated.post(use: createCollection)
    }
    
    func getMyCollections(_ request: Request) async throws -> GameCollectionListResponse {
        let useCase = try await request.resolveRequired(GetUserCollectionsUseCase.self)
        let result = try await useCase.execute(.init(
            userId: try request.user.requireID(),
            includePrivate: true
        ))
        
        return GameCollectionListResponse(
            collections: result.collections.map(GameCollectionResponse.init)
        )
    }
    
    func createCollection(_ request: Request) async throws -> Response {
        let input = try request.content.decode(CreateGameCollectionRequest.self)
        
        let useCase = try await request.resolveRequired(CreateGameCollectionUseCase.self)
        let result = try await useCase.execute(.init(
            name: input.name,
            description: input.description,
            isPublic: input.isPublic,
            userId: try request.user.requireID()
        ))
        
        return GameCollectionResponse(
            id: result.collectionId,
            name: result.name,
            description: input.description,
            isPublic: input.isPublic,
            createdAt: result.createdAt
        ).encodeResponse(status: .created, for: request)
    }
}
```

#### 3. Service Registration

```swift
// In Application-Setup.swift
extension Application.ServiceRegistry {
    func registerGameCollectionServices() {
        // Repository
        register(GameCollectionRepository.self) { app in
            return DatabaseGameCollectionRepository(database: app.db)
        }
        
        // Use Cases
        register(CreateGameCollectionUseCase.self) { app in
            return CreateGameCollectionUseCase(
                collectionRepository: try await app.resolveRequired(GameCollectionRepository.self)
            )
        }
        
        register(GetUserCollectionsUseCase.self) { app in
            return GetUserCollectionsUseCase(
                collectionRepository: try await app.resolveRequired(GameCollectionRepository.self)
            )
        }
    }
}
```

#### 4. Testing

```swift
final class GameCollectionUseCaseTests: UnitTestCase {
    var createUseCase: CreateGameCollectionUseCase!
    var getUseCase: GetUserCollectionsUseCase!
    var mockRepository: TestGameCollectionRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockRepository = TestGameCollectionRepository()
        createUseCase = CreateGameCollectionUseCase(collectionRepository: mockRepository)
        getUseCase = GetUserCollectionsUseCase(collectionRepository: mockRepository)
    }
    
    func testCreateCollection() async throws {
        let user = try testWorld.users.testUser()
        
        let result = try await createUseCase.execute(.init(
            name: "My Favorites",
            description: "Games I love",
            isPublic: true,
            userId: user.requireID()
        ))
        
        XCTAssertEqual(result.name, "My Favorites")
        XCTAssertNotNil(result.collectionId)
        XCTAssertEqual(mockRepository.collections.count, 1)
    }
}
```

This comprehensive guide provides the patterns and examples needed to maintain architectural consistency while adding new features to the Clean Architecture implementation.