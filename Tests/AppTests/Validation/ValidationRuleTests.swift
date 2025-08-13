import XCTest
@testable import App

final class ValidationRuleTests: XCTestCase {
    
    // MARK: - String Validation Tests
    
    func testNotEmptyRule() {
        let rule = NotEmptyRule()
        
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertFalse(rule.validate("").isValid)
        XCTAssertEqual(rule.validate("").errorMessage, "Value cannot be empty")
    }
    
    func testMinLengthRule() {
        let rule = MinLengthRule(5)
        
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertTrue(rule.validate("hello world").isValid)
        XCTAssertFalse(rule.validate("hi").isValid)
        XCTAssertEqual(rule.validate("hi").errorMessage, "Must be at least 5 characters long")
        
        // Test custom message
        let customRule = MinLengthRule(3, message: "Too short!")
        XCTAssertEqual(customRule.validate("ab").errorMessage, "Too short!")
    }
    
    func testMaxLengthRule() {
        let rule = MaxLengthRule(5)
        
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertTrue(rule.validate("hi").isValid)
        XCTAssertFalse(rule.validate("hello world").isValid)
        XCTAssertEqual(rule.validate("hello world").errorMessage, "Must be at most 5 characters long")
    }
    
    func testPatternRule() {
        let rule = PatternRule(
            pattern: "^[A-Z][a-z]+$",
            message: "Must start with capital letter"
        )
        
        XCTAssertTrue(rule.validate("Hello").isValid)
        XCTAssertFalse(rule.validate("hello").isValid)
        XCTAssertFalse(rule.validate("HELLO").isValid)
        XCTAssertEqual(rule.validate("hello").errorMessage, "Must start with capital letter")
    }
    
    func testEmailRule() {
        let rule = EmailRule()
        
        XCTAssertTrue(rule.validate("user@example.com").isValid)
        XCTAssertTrue(rule.validate("test.user+tag@example.co.uk").isValid)
        XCTAssertFalse(rule.validate("invalid").isValid)
        XCTAssertFalse(rule.validate("@example.com").isValid)
        XCTAssertFalse(rule.validate("user@").isValid)
    }
    
    // MARK: - Numeric Validation Tests
    
    func testRangeRule() {
        let rule = RangeRule(1...10)
        
        XCTAssertTrue(rule.validate(5).isValid)
        XCTAssertTrue(rule.validate(1).isValid)
        XCTAssertTrue(rule.validate(10).isValid)
        XCTAssertFalse(rule.validate(0).isValid)
        XCTAssertFalse(rule.validate(11).isValid)
    }
    
    func testMinRule() {
        let rule = MinRule(18, message: "Must be 18 or older")
        
        XCTAssertTrue(rule.validate(18).isValid)
        XCTAssertTrue(rule.validate(25).isValid)
        XCTAssertFalse(rule.validate(17).isValid)
        XCTAssertEqual(rule.validate(17).errorMessage, "Must be 18 or older")
    }
    
    func testMaxRule() {
        let rule = MaxRule(100.0)
        
        XCTAssertTrue(rule.validate(50.0).isValid)
        XCTAssertTrue(rule.validate(100.0).isValid)
        XCTAssertFalse(rule.validate(100.1).isValid)
    }
    
    // MARK: - Composite Rule Tests
    
    func testAndRule() {
        let rule = AndRule(
            MinLengthRule(5),
            MaxLengthRule(10),
            PatternRule(pattern: "^[a-z]+$", message: "Lowercase only")
        )
        
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertFalse(rule.validate("hi").isValid)  // Too short
        XCTAssertFalse(rule.validate("helloworldtest").isValid)  // Too long
        XCTAssertFalse(rule.validate("Hello").isValid)  // Capital letter
    }
    
    func testOrRule() {
        let rule = OrRule(
            EmailRule(message: "Invalid email"),
            PatternRule(pattern: "^[a-zA-Z0-9_]+$", message: "Invalid username")
        )
        
        XCTAssertTrue(rule.validate("user@example.com").isValid)  // Valid email
        XCTAssertTrue(rule.validate("username123").isValid)  // Valid username
        XCTAssertFalse(rule.validate("invalid@").isValid)  // Neither valid
    }
    
    func testNotRule() {
        let rule = NotRule(
            PatternRule(pattern: "^test", message: ""),
            message: "Cannot start with 'test'"
        )
        
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertFalse(rule.validate("test123").isValid)
        XCTAssertEqual(rule.validate("test").errorMessage, "Cannot start with 'test'")
    }
    
    // MARK: - Custom Rule Tests
    
    func testCustomRuleWithClosure() {
        let rule = CustomRule<String> { value in
            value.count % 2 == 0 ? .valid : .invalid("Must have even length")
        }
        
        XCTAssertTrue(rule.validate("hi").isValid)
        XCTAssertTrue(rule.validate("test").isValid)
        XCTAssertFalse(rule.validate("hello").isValid)
    }
    
    func testCustomRuleWithBooleanClosure() {
        let rule = CustomRule<Int>(
            { $0 > 0 },
            message: "Must be positive"
        )
        
        XCTAssertTrue(rule.validate(1).isValid)
        XCTAssertFalse(rule.validate(0).isValid)
        XCTAssertFalse(rule.validate(-1).isValid)
    }
    
    // MARK: - Optional Value Tests
    
    func testOptionalRule() {
        let rule = OptionalRule(MinLengthRule(5))
        
        XCTAssertTrue(rule.validate(nil).isValid)  // nil is valid
        XCTAssertTrue(rule.validate("hello").isValid)
        XCTAssertFalse(rule.validate("hi").isValid)
    }
    
    func testRequiredRule() {
        let rule = RequiredRule<String>()
        
        XCTAssertTrue(rule.validate("value").isValid)
        XCTAssertFalse(rule.validate(nil).isValid)
        XCTAssertEqual(rule.validate(nil).errorMessage, "Value is required")
    }
    
    // MARK: - Complex Validation Scenarios
    
    func testPasswordValidation() {
        // Password must be 8-20 chars with at least one letter and one number
        let rule = AndRule(
            MinLengthRule(8, message: "Password too short"),
            MaxLengthRule(20, message: "Password too long"),
            PatternRule(
                pattern: ".*[A-Za-z].*",
                message: "Must contain at least one letter"
            ),
            PatternRule(
                pattern: ".*[0-9].*",
                message: "Must contain at least one number"
            )
        )
        
        XCTAssertTrue(rule.validate("password123").isValid)
        XCTAssertFalse(rule.validate("pass").isValid)  // Too short
        XCTAssertFalse(rule.validate("password").isValid)  // No number
        XCTAssertFalse(rule.validate("12345678").isValid)  // No letter
    }
    
    func testUsernameValidation() {
        // Username: 3-20 chars, alphanumeric with underscores
        let rule = AndRule(
            MinLengthRule(3, message: "Username too short"),
            MaxLengthRule(20, message: "Username too long"),
            PatternRule(
                pattern: "^[a-zA-Z0-9_]+$",
                message: "Username can only contain letters, numbers, and underscores"
            )
        )
        
        XCTAssertTrue(rule.validate("user_123").isValid)
        XCTAssertTrue(rule.validate("JohnDoe").isValid)
        XCTAssertFalse(rule.validate("ab").isValid)  // Too short
        XCTAssertFalse(rule.validate("user@domain").isValid)  // Invalid character
    }
}