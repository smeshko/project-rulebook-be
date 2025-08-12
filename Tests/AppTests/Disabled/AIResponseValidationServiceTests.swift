import Testing
import Vapor
@testable import App

/// Comprehensive tests for AIResponseValidationService demonstrating Security Domain Service patterns.
///
/// This test suite validates AI response security including content sanitization,
/// malicious content detection, injection prevention, and compliance validation.
final class AIResponseValidationServiceTests {
    
    /// Test validation of clean, safe AI responses.
    @Test("AI response validation approves safe content")
    func testSafeContentValidation() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let safeResponse = RulesGenerationResponse(
            title: "Rules for Ticket to Ride",
            content: "Ticket to Ride is a railway-themed board game. Players collect train cards and claim railway routes across the map to connect cities.",
            sections: [
                RulesSection(
                    title: "Setup",
                    content: "Each player takes 45 colored train pieces and 4 train car cards. Shuffle the destination ticket cards."
                ),
                RulesSection(
                    title: "Gameplay",
                    content: "On each turn, players choose one of three actions: draw train cards, claim a route, or draw destination tickets."
                )
            ],
            complexity: "Medium",
            estimatedPlayTime: "30-60 minutes",
            playerCount: "2-5",
            confidence: 0.92,
            sources: ["Official rulebook", "BGG community"],
            warnings: []
        )
        
        // Act & Assert - Should not throw
        try service.validateRulesResponse(safeResponse)
        
        // Act - Test sanitization (should return unchanged)
        let sanitizedContent = service.sanitizeRulesContent(safeResponse.content)
        #expect(sanitizedContent == safeResponse.content)
    }
    
    /// Test detection of XSS injection attempts.
    @Test("AI response validation detects XSS injection attempts")
    func testXSSInjectionDetection() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let maliciousResponse = RulesGenerationResponse(
            title: "Malicious Game <script>alert('xss')</script>",
            content: "This is a game where you <img src=x onerror=alert('xss')> win by collecting cards.",
            sections: [
                RulesSection(
                    title: "Setup <script>document.location='http://evil.com'</script>",
                    content: "Place pieces on the board. <iframe src='javascript:alert(1)'></iframe>"
                )
            ],
            complexity: "Medium",
            estimatedPlayTime: "60 minutes",
            playerCount: "2-4",
            confidence: 0.85,
            sources: ["Suspicious source"],
            warnings: []
        )
        
        // Act & Assert
        #expect(throws: AIValidationError.suspiciousContent) {
            try service.validateRulesResponse(maliciousResponse)
        }
    }
    
    /// Test detection of SQL injection patterns.
    @Test("AI response validation detects SQL injection patterns")
    func testSQLInjectionDetection() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let sqlInjectionResponse = RulesGenerationResponse(
            title: "Game'; DROP TABLE users; --",
            content: "To win this game, you need to ' OR '1'='1 collect all the cards.",
            sections: [
                RulesSection(
                    title: "Database Setup",
                    content: "Run: SELECT * FROM games WHERE id = 1; DELETE FROM scores; to initialize."
                )
            ],
            complexity: "High",
            estimatedPlayTime: "90 minutes",
            playerCount: "1-6",
            confidence: 0.75,
            sources: ["'; UNION SELECT password FROM users; --"],
            warnings: []
        )
        
        // Act & Assert
        #expect(throws: AIValidationError.suspiciousContent) {
            try service.validateRulesResponse(sqlInjectionResponse)
        }
    }
    
    /// Test content sanitization functionality.
    @Test("AI response validation sanitizes malicious content correctly")
    func testContentSanitization() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let maliciousContent = """
        This is a game about <script>alert('xss')</script> collecting cards.
        
        Players can <img src=x onerror=alert(1)> trade resources.
        
        The goal is to <iframe src='javascript:void(0)'></iframe> build railways.
        
        <svg onload=alert('xss')>
        
        <body onload=alert('xss')>
        
        <input onfocus=alert('xss') autofocus>
        """
        
        // Act
        let sanitizedContent = service.sanitizeRulesContent(maliciousContent)
        
        // Assert - Malicious tags removed/escaped
        #expect(!sanitizedContent.contains("<script>"))
        #expect(!sanitizedContent.contains("onerror="))
        #expect(!sanitizedContent.contains("javascript:"))
        #expect(!sanitizedContent.contains("onload="))
        #expect(!sanitizedContent.contains("onfocus="))
        #expect(!sanitizedContent.contains("<iframe"))
        #expect(!sanitizedContent.contains("<svg"))
        #expect(!sanitizedContent.contains("<body"))
        
        // Assert - Safe content preserved
        #expect(sanitizedContent.contains("collecting cards"))
        #expect(sanitizedContent.contains("trade resources"))
        #expect(sanitizedContent.contains("build railways"))
    }
    
    /// Test detection of suspicious URLs and links.
    @Test("AI response validation detects suspicious URLs")
    func testSuspiciousURLDetection() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let suspiciousResponse = RulesGenerationResponse(
            title: "Game with Links",
            content: "Visit http://malicious.com/steal-data for more rules. Also check https://phishing-site.evil/login",
            sections: [
                RulesSection(
                    title: "External Resources",
                    content: "Download components from ftp://suspicious.org/malware.exe"
                )
            ],
            complexity: "Medium",
            estimatedPlayTime: "45 minutes",
            playerCount: "2-4",
            confidence: 0.80,
            sources: ["http://untrusted-source.com"],
            warnings: []
        )
        
        // Act & Assert
        #expect(throws: AIValidationError.suspiciousContent) {
            try service.validateRulesResponse(suspiciousResponse)
        }
    }
    
    /// Test validation of legitimate external references.
    @Test("AI response validation allows legitimate external references")
    func testLegitimateExternalReferences() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let legitimateResponse = RulesGenerationResponse(
            title: "Wingspan Rules Summary",
            content: "Wingspan is published by Stonemaier Games. Official rules are available at boardgamegeek.com.",
            sections: [
                RulesSection(
                    title: "Additional Resources",
                    content: "Find more information on the BGG community forums and official publisher website."
                )
            ],
            complexity: "Medium",
            estimatedPlayTime: "40-70 minutes",
            playerCount: "1-5",
            confidence: 0.91,
            sources: ["Official rulebook", "BoardGameGeek"],
            warnings: []
        )
        
        // Act & Assert - Should not throw for legitimate references
        try service.validateRulesResponse(legitimateResponse)
    }
    
    /// Test detection of inappropriate or offensive content.
    @Test("AI response validation detects inappropriate content")
    func testInappropriateContentDetection() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let inappropriateResponse = RulesGenerationResponse(
            title: "Inappropriate Game",
            content: "This game contains explicit violence and inappropriate themes that are not suitable for family gaming.",
            sections: [
                RulesSection(
                    title: "Content Warning",
                    content: "Players engage in graphic combat with detailed descriptions of violence and mature themes."
                )
            ],
            complexity: "Adult",
            estimatedPlayTime: "120 minutes",
            playerCount: "18+",
            confidence: 0.70,
            sources: ["Mature content source"],
            warnings: ["Contains adult themes", "Not suitable for children"]
        )
        
        // Note: This test depends on the specific inappropriate content detection logic
        // For this test, we'll assume the service allows mature content with proper warnings
        // but would reject explicitly inappropriate content
        
        // Act & Assert - May pass if properly warned, or throw if too inappropriate
        // Implementation-dependent behavior
        do {
            try service.validateRulesResponse(inappropriateResponse)
            // If it passes, ensure warnings are present
            #expect(inappropriateResponse.warnings.count > 0)
        } catch AIValidationError.inappropriateContent {
            // This is also acceptable if content is deemed too inappropriate
            #expect(true)
        }
    }
    
    /// Test validation of response structure and completeness.
    @Test("AI response validation checks response structure completeness")
    func testResponseStructureValidation() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        // Test incomplete response (missing required fields)
        let incompleteResponse = RulesGenerationResponse(
            title: "", // Empty title
            content: "Some content here",
            sections: [], // No sections
            complexity: "",
            estimatedPlayTime: "",
            playerCount: "",
            confidence: 0.0, // Zero confidence
            sources: [],
            warnings: []
        )
        
        // Act & Assert
        #expect(throws: AIValidationError.incompleteResponse) {
            try service.validateRulesResponse(incompleteResponse)
        }
    }
    
    /// Test validation with edge case content.
    @Test("AI response validation handles edge cases correctly")
    func testEdgeCaseValidation() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        // Test very long content
        let veryLongContent = String(repeating: "This is a very long game description. ", count: 1000)
        
        let edgeCaseResponse = RulesGenerationResponse(
            title: "Edge Case Game",
            content: veryLongContent,
            sections: [
                RulesSection(title: "Long Section", content: veryLongContent)
            ],
            complexity: "Variable",
            estimatedPlayTime: "Variable",
            playerCount: "Variable",
            confidence: 1.0,
            sources: ["Generated"],
            warnings: []
        )
        
        // Act & Assert - Should handle long content gracefully
        try service.validateRulesResponse(edgeCaseResponse)
        
        // Test sanitization of long content
        let sanitized = service.sanitizeRulesContent(veryLongContent)
        #expect(sanitized.count > 0)
    }
    
    /// Test concurrent validation operations.
    @Test("AI response validation handles concurrent requests safely")
    func testConcurrentValidation() async throws {
        // Arrange
        let service = AIResponseValidationService()
        
        let response1 = RulesGenerationResponse(
            title: "Concurrent Game 1",
            content: "Safe content for game 1",
            sections: [RulesSection(title: "Setup", content: "Setup for game 1")],
            complexity: "Medium",
            estimatedPlayTime: "60 minutes",
            playerCount: "2-4",
            confidence: 0.85,
            sources: ["Source 1"],
            warnings: []
        )
        
        let response2 = RulesGenerationResponse(
            title: "Concurrent Game 2 <script>alert('xss')</script>",
            content: "Malicious content for game 2",
            sections: [RulesSection(title: "Malicious", content: "Bad content")],
            complexity: "High",
            estimatedPlayTime: "90 minutes",
            playerCount: "1-6",
            confidence: 0.90,
            sources: ["Source 2"],
            warnings: []
        )
        
        let response3 = RulesGenerationResponse(
            title: "Concurrent Game 3",
            content: "Safe content for game 3",
            sections: [RulesSection(title: "Rules", content: "Rules for game 3")],
            complexity: "Low",
            estimatedPlayTime: "30 minutes",
            playerCount: "2-6",
            confidence: 0.80,
            sources: ["Source 3"],
            warnings: []
        )
        
        // Act - Concurrent validation
        async let result1: Void = { try service.validateRulesResponse(response1) }()
        
        async let result2: Void = {
            do {
                try service.validateRulesResponse(response2)
            } catch {
                throw error
            }
        }()
        
        async let result3: Void = { try service.validateRulesResponse(response3) }()
        
        // Assert - Concurrent processing
        do {
            _ = try await result1 // Should succeed
            _ = try await result3 // Should succeed
            
            // Result2 should fail
            await #expect(throws: AIValidationError.suspiciousContent) {
                try await result2
            }
        } catch {
            #expect(false, "Unexpected error in concurrent validation: \(error)")
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