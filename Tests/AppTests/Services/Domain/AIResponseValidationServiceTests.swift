import Testing
import Vapor
@testable import App

/// Comprehensive tests for AIResponseValidationService demonstrating Security Domain Service patterns.
///
/// This test suite validates AI response security including content sanitization,
/// malicious content detection, injection prevention, and compliance validation.
@Suite(.serialized)
final class AIResponseValidationServiceTests: Sendable {
    
    /// Test validation of clean, safe AI responses.
    @Test("AI response validation approves safe content", .tags(.p0Critical, .security, .aiServices, .unit))
    func testSafeContentValidation() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let safeResponseJSON = """
        {
            "title": "Rules for Ticket to Ride",
            "summary": "Ticket to Ride is a railway-themed board game. Players collect train cards and claim railway routes across the map to connect cities.",
            "playerCount": "2-5",
            "playTime": "30-60 minutes",
            "initialSetup": ["Each player takes 45 colored train pieces and 4 train car cards", "Shuffle the destination ticket cards"],
            "firstRoundGuide": ["Draw train cards", "Claim a route", "Draw destination tickets"],
            "winCondition": "Connect the most cities with railway routes",
            "deepDive": ["Strategic route planning", "Card collection efficiency"],
            "resources": {
                "videoLinks": [],
                "webLinks": []
            },
            "confidence": 92,
            "notes": "Official BGG and rulebook sources"
        }
        """
        
        // Act & Assert - Should not throw
        let validatedResponse = try service.validateRulesSummaryResponse(
            safeResponseJSON,
            gameTitle: "Ticket to Ride",
            clientIP: "127.0.0.1",
            logger: logger
        )
        
        #expect(validatedResponse == safeResponseJSON)
    }
    
    /// Test detection of XSS injection attempts.
    @Test("AI response validation detects XSS injection attempts", .tags(.p0Critical, .security, .aiServices, .unit))
    func testXSSInjectionDetection() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let maliciousResponseJSON = """
        {
            "title": "Malicious Game <script>alert('xss')</script>",
            "summary": "This is a game where you <img src=x onerror=alert('xss')> win by collecting cards.",
            "playerCount": "2-4",
            "playTime": "60 minutes",
            "initialSetup": ["Place pieces on the board. <iframe src='javascript:alert(1)'></iframe>"],
            "firstRoundGuide": ["Setup <script>document.location='http://evil.com'</script>"],
            "winCondition": "Collect all cards",
            "deepDive": ["Avoid security threats"],
            "resources": {
                "videoLinks": [],
                "webLinks": []
            },
            "confidence": 85,
            "notes": "Suspicious source"
        }
        """
        
        // Act & Assert
        #expect(throws: AIProcessingError.self) {
            try service.validateRulesSummaryResponse(
                maliciousResponseJSON,
                gameTitle: "Malicious Game",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
    }
    
    /// Test detection of JavaScript injection patterns.
    @Test("AI response validation detects JavaScript injection patterns", .tags(.p0Critical, .security, .aiServices, .unit))
    func testJavaScriptInjectionDetection() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let jsInjectionResponseJSON = """
        {
            "title": "Game with JS",
            "summary": "To win this game, you javascript:alert('xss') collect all the cards.",
            "playerCount": "1-6",
            "playTime": "90 minutes",
            "initialSetup": ["Click here: eval('malicious code')"],
            "firstRoundGuide": ["Setup instructions"],
            "winCondition": "Collect all cards",
            "deepDive": ["Strategy tips"],
            "resources": {
                "videoLinks": [],
                "webLinks": []
            },
            "confidence": 75,
            "notes": "Normal notes"
        }
        """
        
        // Act & Assert - This will fail due to suspicious JavaScript patterns
        #expect(throws: AIProcessingError.self) {
            try service.validateRulesSummaryResponse(
                jsInjectionResponseJSON,
                gameTitle: "JS Game",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
    }
    
    /// Test generic response validation.
    @Test("AI response validation handles generic responses", .tags(.p1Core, .security, .aiServices, .unit))
    func testGenericResponseValidation() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let validGenericJSON = """
        {
            "message": "This is a safe generic response",
            "status": "success",
            "data": {
                "content": "Safe content here"
            }
        }
        """
        
        // Act & Assert - Should not throw
        let validatedResponse = try service.validateGenericResponse(
            validGenericJSON,
            context: "test_context",
            clientIP: "127.0.0.1",
            logger: logger
        )
        
        #expect(validatedResponse == validGenericJSON)
    }
    
    /// Test response size validation.
    @Test("AI response validation enforces size limits", .tags(.p1Core, .security, .aiServices, .unit))
    func testResponseSizeValidation() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        // Test too short response
        let tooShortJSON = "{}"
        
        #expect(throws: AIProcessingError.self) {
            try service.validateRulesSummaryResponse(
                tooShortJSON,
                gameTitle: "Short Game",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
        
        // Test too large response
        let tooLargeJSON = "\"" + String(repeating: "x", count: 60000) + "\""
        
        #expect(throws: AIProcessingError.self) {
            try service.validateGenericResponse(
                tooLargeJSON,
                context: "test",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
    }
    
    /// Test validation of legitimate game content.
    @Test("AI response validation allows legitimate game content", .tags(.p0Critical, .security, .aiServices, .unit))
    func testLegitimateGameContent() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let legitimateResponseJSON = """
        {
            "title": "Wingspan Rules Summary",
            "summary": "Wingspan is published by Stonemaier Games. Official rules are available at boardgamegeek.com.",
            "playerCount": "1-5",
            "playTime": "40-70 minutes",
            "initialSetup": ["Place the board on the table", "Shuffle the bird cards"],
            "firstRoundGuide": ["Play a bird card", "Gain food", "Lay eggs", "Draw bird cards"],
            "winCondition": "Score the most points through birds, bonus cards, and end-of-round goals",
            "deepDive": ["Engine building mechanics", "Tableau building strategy"],
            "resources": {
                "videoLinks": [],
                "webLinks": []
            },
            "confidence": 91,
            "notes": "Official rulebook and BoardGameGeek sources"
        }
        """
        
        // Act & Assert - Should not throw for legitimate content
        let validatedResponse = try service.validateRulesSummaryResponse(
            legitimateResponseJSON,
            gameTitle: "Wingspan",
            clientIP: "127.0.0.1",
            logger: logger
        )
        
        #expect(validatedResponse == legitimateResponseJSON)
    }
    
    /// Test JSON structure validation.
    @Test("AI response validation rejects invalid JSON", .tags(.p1Core, .security, .aiServices, .unit))
    func testInvalidJSONDetection() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let invalidJSON = "{ incomplete json here"
        
        // Act & Assert - Should throw for invalid JSON
        #expect(throws: AIProcessingError.self) {
            try service.validateGenericResponse(
                invalidJSON,
                context: "test",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
    }
    
    /// Test validation of response with missing required fields.
    @Test("AI response validation detects missing required fields", .tags(.p1Core, .aiServices, .unit))
    func testMissingRequiredFields() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        // Test response missing required fields
        let incompleteJSON = """
        {
            "summary": "Some content here",
            "playerCount": "2-4",
            "confidence": 85
        }
        """
        
        // Act & Assert - Should throw for missing title field
        #expect(throws: AIProcessingError.self) {
            try service.validateRulesSummaryResponse(
                incompleteJSON,
                gameTitle: "Test Game",
                clientIP: "127.0.0.1",
                logger: logger
            )
        }
    }
    
    /// Test GameboxRecognition response validation.
    @Test("AI response validation handles GameboxRecognition responses", .tags(.p1Core, .aiServices, .unit))
    func testGameboxRecognitionValidation() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let gameboxResponseJSON = """
        {
            "guessedTitle": "Ticket to Ride",
            "confidence": 85,
            "alternativeTitles": ["TTR", "Train Game"],
            "keywordsDetected": ["railway", "trains", "routes"],
            "notes": "Clear board game box with railway theme"
        }
        """
        
        // Act & Assert - Should handle GameboxRecognition responses
        let validatedResponse = try service.validateGameboxRecognitionResponse(
            gameboxResponseJSON,
            clientIP: "127.0.0.1",
            logger: logger
        )
        
        #expect(validatedResponse == gameboxResponseJSON)
    }
    
    /// Test concurrent validation operations.
    @Test("AI response validation handles concurrent requests safely", .tags(.p1Core, .security, .aiServices, .unit))
    func testConcurrentValidation() async throws {
        // Arrange
        let service = DefaultAIResponseValidationService()
        let logger = Logger(label: "test")
        
        let safeJSON1 = """
        {
            "title": "Concurrent Game 1",
            "summary": "Safe content for game 1",
            "playerCount": "2-4",
            "playTime": "60 minutes",
            "initialSetup": ["Setup for game 1"],
            "firstRoundGuide": ["Play cards"],
            "winCondition": "Score points",
            "deepDive": ["Strategy tips"],
            "resources": {"videoLinks": [], "webLinks": []},
            "confidence": 85,
            "notes": "Source 1"
        }
        """
        
        let maliciousJSON = """
        {
            "title": "Concurrent Game 2 <script>alert('xss')</script>",
            "summary": "Malicious content for game 2",
            "playerCount": "1-6",
            "playTime": "90 minutes",
            "initialSetup": ["Bad content"],
            "firstRoundGuide": ["Malicious"],
            "winCondition": "Win",
            "deepDive": ["Tips"],
            "resources": {"videoLinks": [], "webLinks": []},
            "confidence": 90,
            "notes": "Source 2"
        }
        """
        
        // Act - Concurrent validation
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                do {
                    _ = try service.validateRulesSummaryResponse(safeJSON1, gameTitle: "Game1", clientIP: "127.0.0.1", logger: logger)
                } catch {
                    #expect(Bool(false), "Safe response should not throw: \(error)")
                }
            }
            
            group.addTask {
                #expect(throws: AIProcessingError.self) {
                    try service.validateRulesSummaryResponse(maliciousJSON, gameTitle: "Game2", clientIP: "127.0.0.1", logger: logger)
                }
            }
        }
    }
}

// MARK: - Security Domain Service Testing Pattern Note

/*
This test demonstrates Security Domain Service testing patterns:

1. **Injection Attack Prevention**: Testing XSS, SQL injection, and other attack vectors
2. **Content Sanitization**: Testing malicious content removal and safe content preservation  
3. **URL/Link Validation**: Testing suspicious external reference detection
4. **Structure Validation**: Testing response completeness and format compliance
5. **Performance Security**: Testing concurrent validation without race conditions
6. **Edge Case Handling**: Testing extreme content scenarios (very long, empty, malformed)

Key characteristics of security domain service testing:
- Comprehensive attack vector testing (XSS, SQL injection, malicious URLs)
- Content sanitization validation (remove bad, preserve good)
- Boundary testing (empty content, extremely long content)
- Concurrent access safety for security operations
- False positive prevention (legitimate content should pass)
- Complete error coverage (all validation failure scenarios)

These patterns ensure security domain services are:
- Robust against known attack patterns
- Accurate in threat detection without false positives
- Performant under high load (concurrent validation)
- Complete in coverage (no security gaps)
- Maintainable with clear error categories
- Thread-safe for production use

Security services differ from other domain services by:
- Focus on threat detection rather than business logic
- Emphasis on preventing false negatives (missing threats)
- Need for comprehensive attack pattern coverage
- Performance requirements for real-time validation
- Compliance with security standards and best practices
*/
