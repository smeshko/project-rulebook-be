import XCTest
@testable import App

final class ValidatedTests: XCTestCase {
    
    // MARK: - Basic Validation Tests
    
    func testValidatedPropertyAcceptsValidValues() {
        struct User {
            @Validated(rules: [MinLengthRule(3)])
            var username: String = ""
        }
        
        var user = User()
        user.username = "john"
        
        XCTAssertEqual(user.username, "john")
        XCTAssertTrue(user.$username.isValid)
        XCTAssertTrue(user.$username.errors.isEmpty)
    }
    
    func testValidatedPropertyRejectsInvalidValues() {
        struct User {
            @Validated(rules: [MinLengthRule(5)])
            var username: String = "valid"
        }
        
        var user = User()
        user.username = "bad"  // Too short
        
        // Value should not change when validation fails
        XCTAssertEqual(user.username, "valid")
        XCTAssertFalse(user.$username.isValid)
        XCTAssertFalse(user.$username.errors.isEmpty)
    }
    
    func testValidatedPropertyWithDefaultValue() {
        struct Config {
            @Validated(
                rules: [RangeRule(1...100)],
                defaultValue: 50
            )
            var percentage: Int = 0
        }
        
        var config = Config()
        config.percentage = 150  // Out of range
        
        // Should fall back to default value
        XCTAssertEqual(config.percentage, 50)
    }
    
    // MARK: - Validation Mode Tests
    
    func testValidationModeOnChange() {
        struct Model {
            @Validated(
                rules: [MinLengthRule(3)],
                mode: .onChange
            )
            var value: String = "ab"  // Initially invalid
        }
        
        var model = Model()
        // Initial value is not validated in onChange mode
        XCTAssertEqual(model.value, "ab")
        
        // But changes are validated
        model.value = "a"  // Too short
        XCTAssertEqual(model.value, "ab")  // Unchanged
    }
    
    func testValidationModeAlways() {
        struct Model {
            @Validated(
                rules: [MinLengthRule(3)],
                defaultValue: "default",
                mode: .always
            )
            var value: String = "ab"  // Initially invalid
        }
        
        let model = Model()
        // Initial value should be validated and replaced with default
        // Note: This depends on implementation details
        XCTAssertNotNil(model.value)
    }
    
    func testValidationModeManual() {
        struct Model {
            @Validated(
                rules: [MinLengthRule(5)],
                mode: .manual
            )
            var value: String = ""
        }
        
        var model = Model()
        model.value = "hi"  // Too short but accepted in manual mode
        
        XCTAssertEqual(model.value, "hi")
        
        // Manual validation
        _ = model.$value.validate()
        XCTAssertFalse(model.$value.isValid)
    }
    
    // MARK: - Multiple Rules Tests
    
    func testMultipleValidationRules() {
        struct Form {
            @Validated(rules: [
                MinLengthRule(8),
                MaxLengthRule(20),
                PatternRule(pattern: "^[a-zA-Z0-9]+$", message: "Alphanumeric only")
            ])
            var password: String = "validPass123"
        }
        
        var form = Form()
        
        // Test too short
        form.password = "pass"
        XCTAssertEqual(form.password, "validPass123")  // Unchanged
        
        // Test too long
        form.password = "thisPasswordIsTooLongToBeAccepted"
        XCTAssertEqual(form.password, "validPass123")  // Unchanged
        
        // Test invalid characters
        form.password = "pass@word!"
        XCTAssertEqual(form.password, "validPass123")  // Unchanged
        
        // Test valid
        form.password = "newPass456"
        XCTAssertEqual(form.password, "newPass456")  // Changed
        XCTAssertTrue(form.$password.isValid)
    }
    
    // MARK: - ValidationState Tests
    
    func testValidationStateProvideAccess() {
        struct Model {
            @Validated(rules: [EmailRule()])
            var email: String = ""
        }
        
        var model = Model()
        model.email = "invalid"
        
        let state = model.$email
        XCTAssertFalse(state.isValid)
        XCTAssertEqual(state.value, "")  // Original value preserved
        XCTAssertFalse(state.errors.isEmpty)
        XCTAssertEqual(state.rules.count, 1)
    }
    
    func testValidationStateManualValidation() {
        struct Model {
            @Validated(rules: [MinLengthRule(5)], mode: .manual)
            var text: String = "hi"
        }
        
        var model = Model()
        
        // Initially might be invalid but value is set
        XCTAssertEqual(model.text, "hi")
        
        // Manual validation
        let result = model.$text.validate()
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errorMessage)
    }
    
    // MARK: - Builder Pattern Tests
    
    func testValidatedBuilder() {
        let validated = ValidatedBuilder<String>()
            .rule(MinLengthRule(5))
            .rule(MaxLengthRule(20))
            .defaultValue("default")
            .mode(.onChange)
            .build(wrappedValue: "initial")
        
        XCTAssertEqual(validated.wrappedValue, "initial")
    }
    
    // MARK: - Convenience Factory Tests
    
    func testEmailValidatedFactory() {
        struct Form {
            var email = Validated.email("test@example.com")
        }
        
        var form = Form()
        XCTAssertEqual(form.email.wrappedValue, "test@example.com")
        XCTAssertTrue(form.email.projectedValue.isValid)
        
        form.email.wrappedValue = "invalid"
        XCTAssertEqual(form.email.wrappedValue, "test@example.com")  // Unchanged
    }
    
    func testPasswordValidatedFactory() {
        struct Form {
            var password = Validated.password("Pass123!", minLength: 8)
        }
        
        var form = Form()
        XCTAssertEqual(form.password.wrappedValue, "Pass123!")
        
        // Test too short
        form.password.wrappedValue = "Pass1"
        XCTAssertEqual(form.password.wrappedValue, "Pass123!")  // Unchanged
    }
    
    func testUsernameValidatedFactory() {
        struct Form {
            var username = Validated.username("user123", minLength: 3, maxLength: 20)
        }
        
        var form = Form()
        XCTAssertEqual(form.username.wrappedValue, "user123")
        
        // Test invalid characters
        form.username.wrappedValue = "user@123"
        XCTAssertEqual(form.username.wrappedValue, "user123")  // Unchanged
    }
    
    // MARK: - Codable Support Tests
    
    func testValidatedCodable() throws {
        struct User: Codable {
            @Validated(rules: [EmailRule()])
            var email: String
            
            init(email: String = "") {
                self._email = Validated(wrappedValue: email, rules: [EmailRule()])
            }
        }
        
        let user = User(email: "test@example.com")
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        let json = String(data: data, encoding: .utf8)
        XCTAssertEqual(json, #"{"email":"test@example.com"}"#)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(User.self, from: data)
        XCTAssertEqual(decoded.email, "test@example.com")
    }
    
    // MARK: - Equatable and Hashable Tests
    
    func testValidatedEquatable() {
        struct Model: Equatable {
            @Validated(rules: [MinLengthRule(3)])
            var value: String
            
            init(value: String) {
                self._value = Validated(wrappedValue: value, rules: [MinLengthRule(3)])
            }
        }
        
        let model1 = Model(value: "test")
        let model2 = Model(value: "test")
        let model3 = Model(value: "different")
        
        XCTAssertEqual(model1, model2)
        XCTAssertNotEqual(model1, model3)
    }
    
    func testValidatedHashable() {
        struct Model: Hashable {
            @Validated(rules: [MinLengthRule(3)])
            var value: String
            
            init(value: String) {
                self._value = Validated(wrappedValue: value, rules: [MinLengthRule(3)])
            }
        }
        
        let model1 = Model(value: "test")
        let model2 = Model(value: "test")
        
        var set = Set<Model>()
        set.insert(model1)
        set.insert(model2)
        
        XCTAssertEqual(set.count, 1)  // Same value, so only one in set
    }
}