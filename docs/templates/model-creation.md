---
title: "Model Creation Template"
description: "Guide for creating database models and DTOs in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Model Creation Template

## When to Use

- Creating Fluent database entities
- Defining request/response DTOs
- Establishing database relationships

## Quick Reference

| Component | Description |
|-----------|-------------|
| Database Model Location | `Sources/App/Modules/{Module}/Database/Models/{Entity}Model.swift` |
| DTO Location | `Sources/App/Modules/{Module}/Models/{Feature}.swift` |
| Required Protocols | `@unchecked Sendable`, `DatabaseModelInterface` |
| Table Naming | snake_case, plural (e.g., `refresh_tokens`) |
| Field Keys | Versioned struct pattern (`FieldKeys.v1`) |

## Database Model Template

### Step 1: Create Model File

Create `Sources/App/Modules/{Module}/Database/Models/{Entity}Model.swift`:

```swift
import Fluent
import Vapor

// MARK: - Model

final class {Entity}Model: @unchecked Sendable, DatabaseModelInterface {

    typealias Module = {Module}Module

    static var schema: String { "{table_name}" }

    // MARK: - Properties

    @ID(key: .id)
    var id: UUID?

    @Field(key: FieldKeys.v1.name)
    var name: String

    @Field(key: FieldKeys.v1.email)
    var email: String

    @OptionalField(key: FieldKeys.v1.description)
    var description: String?

    @Field(key: FieldKeys.v1.isActive)
    var isActive: Bool

    // MARK: - Relationships

    @Parent(key: FieldKeys.v1.userId)
    var user: UserAccountModel

    // MARK: - Timestamps

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    @Timestamp(key: FieldKeys.v1.deletedAt, on: .delete)
    var deletedAt: Date?

    // MARK: - Initializers

    init() { }

    init(
        id: UUID? = nil,
        name: String,
        email: String,
        description: String? = nil,
        isActive: Bool = true,
        userID: UUID
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.description = description
        self.isActive = isActive
        self.$user.id = userID
    }
}

// MARK: - Field Keys

extension {Entity}Model {
    struct FieldKeys {
        struct v1 {
            static var name: FieldKey { "name" }
            static var email: FieldKey { "email" }
            static var description: FieldKey { "description" }
            static var isActive: FieldKey { "is_active" }
            static var userId: FieldKey { "user_id" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
            static var deletedAt: FieldKey { "deleted_at" }
        }
    }
}
```

### Step 2: Add Helper Extensions (Optional)

```swift
// MARK: - Guard Middleware

extension {Entity}Model {
    static func `guard`() -> Middleware {
        {Entity}Model.guardMiddleware(throwing: AuthenticationError.userNotAuthorized)
    }
}

// MARK: - Authenticatable (if needed)

extension {Entity}Model: Authenticatable {}
```

## Property Wrapper Reference

| Wrapper | Use Case | Swift Type | Database |
|---------|----------|------------|----------|
| `@ID` | Primary key | `UUID?` | `uuid` |
| `@Field` | Required field | `String`, `Int`, `Bool`, etc. | varies |
| `@OptionalField` | Optional field | `String?`, `Int?`, etc. | varies |
| `@Timestamp` | Auto-managed date | `Date?` | `datetime` |
| `@Parent` | Foreign key (many-to-one) | `ParentModel` | `uuid` |
| `@Children` | Inverse relation (one-to-many) | `[ChildModel]` | - |
| `@Siblings` | Many-to-many | `[SiblingModel]` | - |
| `@Enum` | Enum stored as string | `MyEnum` | `string` |

## Relationship Patterns

### Parent (Many-to-One)

```swift
@Parent(key: FieldKeys.v1.userId)
var user: UserAccountModel

// In init:
self.$user.id = userID
```

### Children (One-to-Many)

```swift
@Children(for: \.$parent)
var children: [ChildModel]
```

### Siblings (Many-to-Many)

```swift
@Siblings(through: PivotModel.self, from: \.$left, to: \.$right)
var siblings: [SiblingModel]
```

## DTO Template

### Namespace Pattern

Create `Sources/App/Modules/{Module}/Models/{Feature}.swift`:

```swift
import Vapor

// MARK: - {Feature} DTOs

enum {Feature} {

    // MARK: - Create

    enum Create {
        struct Request: Content {
            let name: String
            let email: String
            let description: String?
        }

        struct Response: Content {
            let id: UUID
            let name: String
            let createdAt: Date

            init(from model: {Entity}Model) throws {
                self.id = try model.requireID()
                self.name = model.name
                self.createdAt = model.createdAt ?? Date()
            }
        }
    }

    // MARK: - Update

    enum Update {
        struct Request: Content {
            let name: String?
            let description: String?
        }
    }

    // MARK: - List

    struct ListResponse: Content {
        let items: [Item]
        let total: Int

        struct Item: Content {
            let id: UUID
            let name: String

            init(from model: {Entity}Model) throws {
                self.id = try model.requireID()
                self.name = model.name
            }
        }
    }
}
```

### Validation

```swift
enum {Feature} {
    enum Create {
        struct Request: Content, Validatable {
            let email: String
            let password: String

            static func validations(_ validations: inout Validations) {
                validations.add("email", as: String.self, is: .email)
                validations.add("password", as: String.self, is: .count(8...))
            }
        }
    }
}
```

### Coding Keys (Custom JSON Keys)

```swift
struct Response: Content {
    let userId: UUID
    let userName: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case userName = "user_name"
    }
}
```

## Implementation Checklist

### Database Model

- [ ] `final class` with `@unchecked Sendable`
- [ ] Conforms to `DatabaseModelInterface`
- [ ] `typealias Module` set
- [ ] Static `schema` property with table name
- [ ] `@ID` property for primary key
- [ ] All fields use appropriate property wrappers
- [ ] Timestamps included (createdAt, updatedAt, deletedAt)
- [ ] Empty initializer `init() { }`
- [ ] Convenience initializer with parameters
- [ ] `FieldKeys` extension with versioned struct
- [ ] Field keys use snake_case

### DTOs

- [ ] Conform to `Content` protocol
- [ ] Namespace enum for related types
- [ ] `init(from model:)` for response DTOs
- [ ] Use `requireID()` for model ID
- [ ] Validation for request DTOs (if needed)
- [ ] Never expose sensitive data (passwords, tokens)

## Codebase Examples

- `Sources/App/Modules/Auth/Database/Models/RefreshTokenModel.swift` - Token with parent relation
- `Sources/App/Modules/User/Database/Models/UserAccountModel.swift` - User with auth
- `Sources/App/Modules/Auth/Models/Auth.swift` - DTO namespace pattern

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Missing `@unchecked Sendable` | Required for thread safety in async contexts |
| Wrong FieldKey casing | Use snake_case for database columns |
| No empty initializer | Fluent requires `init() { }` |
| Exposing passwords in DTOs | Never include sensitive fields in responses |
| Forgetting `requireID()` | Use in DTO initializers to safely get ID |
| Wrong `typealias Module` | Must match the module containing this model |
| Missing timestamps | Include for audit trail and soft delete |
