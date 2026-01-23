---
title: "Module Creation Template"
description: "Guide for creating feature modules in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Module Creation Template

## When to Use

- Creating a new feature domain (e.g., Auth, User, RulesGeneration)
- Encapsulating related functionality with its own routes, controllers, and data access
- Adding a complete vertical slice of functionality

## Quick Reference

| Component | Description |
|-----------|-------------|
| Location | `Sources/App/Modules/{Module}/` |
| Protocol | `ModuleInterface` |
| Registration | `Application-Setup.swift` |
| Contains | Router, Controller, Repository, Models, Migrations |

## Directory Structure

```text
Sources/App/Modules/{Module}/
├── {Module}Module.swift           # Module registration
├── {Module}Router.swift           # Route definitions
├── Controllers/
│   └── {Module}Controller.swift   # Request handlers
├── Repositories/
│   └── {Entity}Repository.swift   # Data access
├── Models/
│   └── {Feature}.swift            # DTOs
└── Database/
    ├── Models/
    │   └── {Entity}Model.swift    # Fluent models
    └── Migrations/
        └── {Module}Migrations.swift
```

## Code Template

### Step 1: Create Module File

Create `Sources/App/Modules/{Module}/{Module}Module.swift`:

```swift
import Vapor

struct {Module}Module: ModuleInterface {
    let router = {Module}Router()

    func boot(_ app: Application) throws {
        // Register migrations
        app.migrations.add({Module}Migrations.v1())

        // Boot routes
        try router.boot(routes: app.routes)
    }
}
```

### Step 2: Create Router

Create `Sources/App/Modules/{Module}/{Module}Router.swift`:

```swift
import Vapor
import VaporToOpenAPI

struct {Module}Router: RouteCollection {
    let controller = {Module}Controller()

    func boot(routes: RoutesBuilder) throws {
        let api = routes
            .grouped("api")
            .grouped("v1")
            .grouped("{module-slug}")
            .groupedOpenAPI(tags: .init(
                name: "{Module}",
                description: "Description of this module's functionality"
            ))

        // Public endpoints
        api.post("action", use: controller.publicAction)
            .openAPI(
                summary: "Public action",
                description: "Description of what this does.",
                body: .type({Module}.Action.Request.self),
                response: .type({Module}.Action.Response.self)
            )

        // Protected endpoints
        api
            .grouped(UserAccountModel.guard())
            .get("protected", use: controller.protectedAction)
            .openAPI(
                summary: "Protected action",
                description: "Requires authentication.",
                auth: .bearer(id: "bearerAuth"),
                response: .type({Module}.Protected.Response.self)
            )
    }
}
```

### Step 3: Create Controller

Create `Sources/App/Modules/{Module}/Controllers/{Module}Controller.swift`:

```swift
import Vapor

struct {Module}Controller {

    func publicAction(_ req: Request) async throws -> {Module}.Action.Response {
        // 1. Decode request
        let input = try req.content.decode({Module}.Action.Request.self)

        // 2. Execute business logic
        let result = try await processAction(input, on: req)

        // 3. Return response
        return {Module}.Action.Response(from: result)
    }

    func protectedAction(_ req: Request) async throws -> {Module}.Protected.Response {
        // 1. Get authenticated user
        let user = try req.auth.require(UserAccountModel.self)

        // 2. Execute logic
        let items = try await req.repositories.{entities}.findAll(forUserID: user.requireID())

        // 3. Return response
        return {Module}.Protected.Response(items: items.map { .init(from: $0) })
    }

    private func processAction(_ input: {Module}.Action.Request, on req: Request) async throws -> SomeResult {
        // Business logic implementation
    }
}
```

### Step 4: Create DTOs

Create `Sources/App/Modules/{Module}/Models/{Module}.swift`:

```swift
import Vapor

enum {Module} {

    enum Action {
        struct Request: Content {
            let field: String
        }

        struct Response: Content {
            let id: UUID
            let result: String

            init(from model: {Entity}Model) throws {
                self.id = try model.requireID()
                self.result = model.result
            }
        }
    }

    enum Protected {
        struct Response: Content {
            let items: [Item]

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
}
```

### Step 5: Create Database Model

Create `Sources/App/Modules/{Module}/Database/Models/{Entity}Model.swift`:

```swift
import Fluent
import Vapor

final class {Entity}Model: @unchecked Sendable, DatabaseModelInterface {
    typealias Module = {Module}Module

    static var schema: String { "{table_name}" }

    @ID(key: .id)
    var id: UUID?

    @Field(key: FieldKeys.v1.name)
    var name: String

    @Parent(key: FieldKeys.v1.userId)
    var user: UserAccountModel

    @Timestamp(key: FieldKeys.v1.createdAt, on: .create)
    var createdAt: Date?

    @Timestamp(key: FieldKeys.v1.updatedAt, on: .update)
    var updatedAt: Date?

    @Timestamp(key: FieldKeys.v1.deletedAt, on: .delete)
    var deletedAt: Date?

    init() { }

    init(id: UUID? = nil, name: String, userID: UUID) {
        self.id = id
        self.name = name
        self.$user.id = userID
    }
}

extension {Entity}Model {
    struct FieldKeys {
        struct v1 {
            static var name: FieldKey { "name" }
            static var userId: FieldKey { "user_id" }
            static var createdAt: FieldKey { "created_at" }
            static var updatedAt: FieldKey { "updated_at" }
            static var deletedAt: FieldKey { "deleted_at" }
        }
    }
}
```

### Step 6: Create Migration

Create `Sources/App/Modules/{Module}/Database/Migrations/{Module}Migrations.swift`:

```swift
import Fluent
import Vapor

enum {Module}Migrations {
    struct v1: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema({Entity}Model.schema)
                .id()
                .field({Entity}Model.FieldKeys.v1.name, .string, .required)
                .field({Entity}Model.FieldKeys.v1.userId, .uuid, .required)
                .field({Entity}Model.FieldKeys.v1.createdAt, .datetime)
                .field({Entity}Model.FieldKeys.v1.updatedAt, .datetime)
                .field({Entity}Model.FieldKeys.v1.deletedAt, .datetime)
                .foreignKey(
                    {Entity}Model.FieldKeys.v1.userId,
                    references: UserAccountModel.schema, .id,
                    onDelete: .cascade
                )
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema({Entity}Model.schema).delete()
        }
    }
}
```

### Step 7: Create Repository

Create `Sources/App/Modules/{Module}/Repositories/{Entity}Repository.swift`:

```swift
import Fluent
import Vapor

protocol {Entity}Repository: Repository {
    func find(id: UUID?) async throws -> {Entity}Model?
    func findAll(forUserID userID: UUID) async throws -> [{Entity}Model]
    func create(_ model: {Entity}Model) async throws
    func update(_ model: {Entity}Model) async throws
}

struct Database{Entity}Repository: {Entity}Repository, DatabaseRepository {
    typealias Model = {Entity}Model
    let database: Database

    func find(id: UUID?) async throws -> {Entity}Model? {
        guard let id = id else { return nil }
        return try await {Entity}Model.query(on: database)
            .filter(\.$id == id)
            .with(\.$user)
            .first()
    }

    func findAll(forUserID userID: UUID) async throws -> [{Entity}Model] {
        try await {Entity}Model.query(on: database)
            .filter(\.$user.$id == userID)
            .all()
    }

    func create(_ model: {Entity}Model) async throws {
        try await model.create(on: database)
    }

    func update(_ model: {Entity}Model) async throws {
        try await model.update(on: database)
    }
}

extension Application.Repositories {
    var {entities}: any {Entity}Repository {
        application.{entity}Repository
    }
}
```

### Step 8: Register Module

In `Sources/App/Application-Setup.swift`:

```swift
// Add to ServiceStorageContainer
var {entity}Repository: (any {Entity}Repository)?

// Add Application extension
extension Application {
    var {entity}Repository: any {Entity}Repository {
        get { serviceStorage.{entity}Repository! }
        set { serviceStorage.{entity}Repository = newValue }
    }
}

// In setupRepositories()
func setupRepositories(_ app: Application) throws {
    // ... existing repositories ...
    app.{entity}Repository = Database{Entity}Repository(database: app.db)
}

// In setupModules()
func setupModules(_ app: Application) throws {
    // ... existing modules ...
    try {Module}Module().boot(app)
}
```

## Module Registration Order

Register modules in dependency order:

```swift
func setupModules(_ app: Application) throws {
    // 1. Foundation modules (no dependencies)
    try UserModule().boot(app)

    // 2. Modules that depend on User
    try AuthModule().boot(app)

    // 3. Feature modules
    try {Module}Module().boot(app)

    // 4. Admin/utility modules
    try CacheAdminModule().boot(app)
}
```

## Implementation Checklist

- [ ] Directory structure created
- [ ] `{Module}Module.swift` with `ModuleInterface`
- [ ] `{Module}Router.swift` with `RouteCollection`
- [ ] `{Module}Controller.swift` with handlers
- [ ] `{Entity}Model.swift` with `DatabaseModelInterface`
- [ ] `{Module}Migrations.swift` with `AsyncMigration`
- [ ] `{Entity}Repository.swift` with protocol + implementation
- [ ] DTOs in `Models/{Module}.swift`
- [ ] Repository added to `ServiceStorageContainer`
- [ ] Application extension for repository
- [ ] `Application.Repositories` extension
- [ ] Repository initialized in `setupRepositories()`
- [ ] Module registered in `setupModules()`
- [ ] Migrations registered in module's `boot()`

## Codebase Examples

- `Sources/App/Modules/Auth/` - Full authentication module
- `Sources/App/Modules/User/` - User management module
- `Sources/App/Modules/RulesGeneration/` - Feature module with AI integration
- `Sources/App/Modules/Waitlist/` - Simple CRUD module

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Wrong boot order | Register dependencies first (User before Auth) |
| Missing migration registration | Add `app.migrations.add()` in module's `boot()` |
| Forgetting repository setup | Add to ServiceStorageContainer + Application extension |
| Wrong `typealias Module` | Must match the module containing the model |
| Missing route registration | Call `try router.boot(routes: app.routes)` |
| Not following naming convention | Use `{Module}Module.swift`, `{Module}Router.swift`, etc. |
