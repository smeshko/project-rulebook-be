import Testing
@testable import App

@Suite(.serialized)
struct ValidationRuleTests {
    
    // MARK: - String Validation Tests
    
    @Test("NotEmptyRule validates non-empty strings", .tags(.p1Core, .unit))
    func notEmptyRule() {
        let rule = NotEmptyRule()
        
        #expect(rule.validate("hello").isValid)
        #expect(!rule.validate("").isValid)
        #expect(rule.validate("").errorMessage == "Value cannot be empty")
    }
    
    @Test("MinLengthRule validates minimum string length", .tags(.p1Core, .unit))
    func minLengthRule() {
        let rule = MinLengthRule(5)
        
        #expect(rule.validate("hello").isValid)
        #expect(rule.validate("hello world").isValid)
        #expect(!rule.validate("hi").isValid)
        #expect(rule.validate("hi").errorMessage == "Must be at least 5 characters long")
        
        // Test custom message
        let customRule = MinLengthRule(3, message: "Too short!")
        #expect(customRule.validate("ab").errorMessage == "Too short!")
    }
    
    @Test("MaxLengthRule validates maximum string length", .tags(.p1Core, .unit))
    func maxLengthRule() {
        let rule = MaxLengthRule(5)
        
        #expect(rule.validate("hello").isValid)
        #expect(rule.validate("hi").isValid)
        #expect(!rule.validate("hello world").isValid)
        #expect(rule.validate("hello world").errorMessage == "Must be at most 5 characters long")
    }
    
    @Test("PatternRule validates regex patterns", .tags(.p1Core, .unit))
    func patternRule() {
        let rule = PatternRule(
            pattern: "^[A-Z][a-z]+$",
            message: "Must start with capital letter"
        )
        
        #expect(rule.validate("Hello").isValid)
        #expect(!rule.validate("hello").isValid)
        #expect(!rule.validate("HELLO").isValid)
        #expect(rule.validate("hello").errorMessage == "Must start with capital letter")
    }
    
    @Test("EmailRule validates email addresses", .tags(.p0Critical, .auth, .unit))
    func emailRule() {
        let rule = EmailRule()
        
        #expect(rule.validate("user@example.com").isValid)
        #expect(rule.validate("test.user+tag@example.co.uk").isValid)
        #expect(!rule.validate("invalid").isValid)
        #expect(!rule.validate("@example.com").isValid)
        #expect(!rule.validate("user@").isValid)
    }
    
    // MARK: - Numeric Validation Tests
    
    @Test("RangeRule validates numeric ranges", .tags(.p2Extended, .unit))
    func rangeRule() {
        let rule = RangeRule(1...10)
        
        #expect(rule.validate(5).isValid)
        #expect(rule.validate(1).isValid)
        #expect(rule.validate(10).isValid)
        #expect(!rule.validate(0).isValid)
        #expect(!rule.validate(11).isValid)
    }
    
    @Test("MinRule validates minimum values", .tags(.p2Extended, .unit))
    func minRule() {
        let rule = MinRule(18, message: "Must be 18 or older")
        
        #expect(rule.validate(18).isValid)
        #expect(rule.validate(25).isValid)
        #expect(!rule.validate(17).isValid)
        #expect(rule.validate(17).errorMessage == "Must be 18 or older")
    }
    
    @Test("MaxRule validates maximum values", .tags(.p2Extended, .unit))
    func maxRule() {
        let rule = MaxRule(100.0)
        
        #expect(rule.validate(50.0).isValid)
        #expect(rule.validate(100.0).isValid)
        #expect(!rule.validate(100.1).isValid)
    }
    
    // MARK: - Composite Rule Tests
    
    @Test("AndRule validates all conditions", .tags(.p1Core, .unit))
    func andRule() {
        let rule = AndRule(
            MinLengthRule(5),
            MaxLengthRule(10),
            PatternRule(pattern: "^[a-z]+$", message: "Lowercase only")
        )
        
        #expect(rule.validate("hello").isValid)
        #expect(!rule.validate("hi").isValid)  // Too short
        #expect(!rule.validate("helloworldtest").isValid)  // Too long
        #expect(!rule.validate("Hello").isValid)  // Capital letter
    }
    
    @Test("OrRule validates any condition", .tags(.p1Core, .unit))
    func orRule() {
        let rule = OrRule(
            EmailRule(message: "Invalid email"),
            PatternRule(pattern: "^[a-zA-Z0-9_]+$", message: "Invalid username")
        )
        
        #expect(rule.validate("user@example.com").isValid)  // Valid email
        #expect(rule.validate("username123").isValid)  // Valid username
        #expect(!rule.validate("invalid@").isValid)  // Neither valid
    }
    
    @Test("NotRule validates inverse condition", .tags(.p2Extended, .unit))
    func notRule() {
        let rule = NotRule(
            PatternRule(pattern: "^test", message: ""),
            message: "Cannot start with 'test'"
        )
        
        #expect(rule.validate("hello").isValid)
        #expect(!rule.validate("test123").isValid)
        #expect(rule.validate("test").errorMessage == "Cannot start with 'test'")
    }
    
    // MARK: - Custom Rule Tests
    
    @Test("CustomRule validates with closure", .tags(.p2Extended, .unit))
    func customRuleWithClosure() {
        let rule = CustomRule<String> { value in
            value.count % 2 == 0 ? .valid : .invalid("Must have even length")
        }
        
        #expect(rule.validate("hi").isValid)
        #expect(rule.validate("test").isValid)
        #expect(!rule.validate("hello").isValid)
    }
    
    @Test("CustomRule validates with boolean closure", .tags(.p2Extended, .unit))
    func customRuleWithBooleanClosure() {
        let rule = CustomRule<Int>(
            { $0 > 0 },
            message: "Must be positive"
        )
        
        #expect(rule.validate(1).isValid)
        #expect(!rule.validate(0).isValid)
        #expect(!rule.validate(-1).isValid)
    }
    
    // MARK: - Optional Value Tests
    
    @Test("OptionalRule validates optional values", .tags(.p2Extended, .unit))
    func optionalRule() {
        let rule = OptionalRule(MinLengthRule(5))
        
        #expect(rule.validate(nil).isValid)  // nil is valid
        #expect(rule.validate("hello").isValid)
        #expect(!rule.validate("hi").isValid)
    }
    
    @Test("RequiredRule validates required values", .tags(.p1Core, .unit))
    func requiredRule() {
        let rule = RequiredRule<String>()
        
        #expect(rule.validate("value").isValid)
        #expect(!rule.validate(nil).isValid)
        #expect(rule.validate(nil).errorMessage == "Value is required")
    }
    
    // MARK: - Complex Validation Scenarios
    
    @Test("Complex password validation", .tags(.p0Critical, .auth, .security, .unit))
    func passwordValidation() {
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
        
        #expect(rule.validate("password123").isValid)
        #expect(!rule.validate("pass").isValid)  // Too short
        #expect(!rule.validate("password").isValid)  // No number
        #expect(!rule.validate("12345678").isValid)  // No letter
    }
    
    @Test("Complex username validation", .tags(.p0Critical, .auth, .security, .unit))
    func usernameValidation() {
        // Username: 3-20 chars, alphanumeric with underscores
        let rule = AndRule(
            MinLengthRule(3, message: "Username too short"),
            MaxLengthRule(20, message: "Username too long"),
            PatternRule(
                pattern: "^[a-zA-Z0-9_]+$",
                message: "Username can only contain letters, numbers, and underscores"
            )
        )
        
        #expect(rule.validate("user_123").isValid)
        #expect(rule.validate("JohnDoe").isValid)
        #expect(!rule.validate("ab").isValid)  // Too short
        #expect(!rule.validate("user@domain").isValid)  // Invalid character
    }
}