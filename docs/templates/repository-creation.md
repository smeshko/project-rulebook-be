---
title: "Repository Creation Template"
description: "Guide for creating repositories in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Repository Creation Template

## When to Use

- Creating data access abstractions for database operations
- Encapsulating Fluent queries behind protocol interfaces
- Enabling testability through mock implementations

## Quick Reference

| Component | Description |
|-----------|-------------|
| Location | `Sources/App/Modules/{Module}/Repositories/{Entity}Repository.swift` |
| Base Protocol | `Repository` (from `Sources/App/Common/Framework/Repository.swift`) |
| Implementation | `Database{Entity}Repository` |
| Access Pattern | `req.repositories.{entities}` |
| Storage | `Sources/App/Common/Extensions/Application+Services.swift` |

## Directory Structure

```text
Sources/App/Modules/{Module}/
└── Repositories/
    └── {Entity}Repository.swift    # Protocol + Implementation + Extensions
```

## Code Template

### Step 1: Define Protocol and Implementation

Create `Sources/App/Modules/{Module}/Repositories/{Entity}Repository.swift`:

```swift
import Fluent
import Vapor

// MARK: - Protocol

protocol {Entity}Repository: Repository {
    func find(id: UUID?) async throws -> {Entity}Model?
    func find({uniqueField}: String) async throws -> {Entity}Model?
    func create(_ model: {Entity}Model) async throws
    func update(_ model: {Entity}Model) async throws
    func all() async throws -> [{Entity}Model]
}

// MARK: - Implementation

struct Database{Entity}Repository: {Entity}Repository, DatabaseRepository {
    typealias Model = {Entity}Model
    let database: Database

    func find(id: UUID?) async throws -> {Entity}Model? {
        guard let id = id else { return nil }
        return try await {Entity}Model.query(on: database)
            .filter(\.$id == id)
            .first()
    }

    func find({uniqueField}: String) async throws -> {Entity}Model? {
        try await {Entity}Model.query(on: database)
            .filter(\.${uniqueField} == {uniqueField})
            .first()
    }

    func create(_ model: {Entity}Model) async throws {
        try await model.create(on: database)
    }

    func update(_ model: {Entity}Model) async throws {
        try await model.update(on: database)
    }

    func all() async throws -> [{Entity}Model] {
        try await {Entity}Model.query(on: database).all()
    }
}

// MARK: - Application.Repositories Extension

extension Application.Repositories {
    var {entities}: any {Entity}Repository {
        application.{entity}Repository
    }
}

// MARK: - Request.Services Extension (optional, for direct service access)

extension Request.Services {
    var {entities}: any {Entity}Repository {
        request.application.{entity}Repository
    }
}
```

### Step 2: Register in Application Storage

In `Sources/App/Common/Extensions/Application+Services.swift`:

```swift
// Add to ServiceStorageContainer
final class ServiceStorageContainer: @unchecked Sendable {
    // ... existing ...
    var {entity}Repository: (any {Entity}Repository)?
}

// Add Application extension
extension Application {
    var {entity}Repository: any {Entity}Repository {
        get { serviceStorage.{entity}Repository! }
        set { serviceStorage.{entity}Repository = newValue }
    }
}
```

### Step 3: Initialize in Setup

In `Sources/App/Application-Setup.swift`:

```swift
func setupRepositories(_ app: Application) throws {
    // ... existing repositories ...
    app.{entity}Repository = Database{Entity}Repository(database: app.db)
}
```

## Common Patterns

### With Eager Loading (Relationships)

```swift
func find(id: UUID?) async throws -> {Entity}Model? {
    guard let id = id else { return nil }
    return try await {Entity}Model.query(on: database)
        .filter(\.$id == id)
        .with(\.$user)           // Eager load parent
        .with(\.$items)          // Eager load children
        .first()
}
```

### Parent Relationship Query

```swift
func find(forUserID id: UUID) async throws -> {Entity}Model? {
    try await {Entity}Model.query(on: database)
        .filter(\.$user.$id == id)
        .with(\.$user)
        .first()
}

func delete(forUserID id: UUID) async throws {
    try await {Entity}Model.query(on: database)
        .filter(\.$user.$id == id)
        .delete()
}
```

### Parallel Fetches (N+1 Prevention)

```swift
func findWithRelations(id: UUID) async throws -> (
    entity: {Entity}Model?,
    relatedItems: [RelatedModel]
) {
    async let entityTask = {Entity}Model.query(on: database)
        .filter(\.$id == id)
        .first()

    async let relatedTask = RelatedModel.query(on: database)
        .filter(\.$parent.$id == id)
        .all()

    let (entity, related) = try await (entityTask, relatedTask)
    return (entity: entity, relatedItems: related)
}
```

### Filtered Queries

```swift
func findActive() async throws -> [{Entity}Model] {
    try await {Entity}Model.query(on: database)
        .filter(\.$isActive == true)
        .filter(\.$deletedAt == nil)
        .sort(\.$createdAt, .descending)
        .all()
}

func findPaginated(page: Int, perPage: Int) async throws -> Page<{Entity}Model> {
    try await {Entity}Model.query(on: database)
        .paginate(PageRequest(page: page, per: perPage))
}
```

## Mock for Testing

Create `Tests/AppTests/Mocks/Mock{Entity}Repository.swift`:

```swift
import Vapor
@testable import App

final class Mock{Entity}Repository: {Entity}Repository {
    typealias Model = {Entity}Model

    var items: [UUID: {Entity}Model] = [:]

    func find(id: UUID?) async throws -> {Entity}Model? {
        guard let id = id else { return nil }
        return items[id]
    }

    func find({uniqueField}: String) async throws -> {Entity}Model? {
        items.values.first { $0.{uniqueField} == {uniqueField} }
    }

    func create(_ model: {Entity}Model) async throws {
        if model.id == nil {
            model.id = UUID()
        }
        items[model.id!] = model
    }

    func update(_ model: {Entity}Model) async throws {
        guard let id = model.id else { return }
        items[id] = model
    }

    func all() async throws -> [{Entity}Model] {
        Array(items.values)
    }

    func delete(id: UUID) async throws {
        items.removeValue(forKey: id)
    }

    func count() async throws -> Int {
        items.count
    }

    func `for`(_ req: Request) -> Self {
        self
    }
}
```

## Base Protocol Reference

The `Repository` base protocol from `Sources/App/Common/Framework/Repository.swift`:

```swift
public protocol Repository: RequestService {
    associatedtype Model: DatabaseModelInterface

    func delete(id: UUID) async throws
    func count() async throws -> Int
}

public protocol DatabaseRepository: Repository {
    var database: Database { get }
    init(database: Database)
}

// Default implementations provided for delete and count
```

## Implementation Checklist

- [ ] Protocol extends `Repository`
- [ ] Implementation conforms to `DatabaseRepository`
- [ ] `typealias Model = {Entity}Model` declared
- [ ] `let database: Database` property
- [ ] All CRUD methods implemented with `async throws`
- [ ] Eager loading with `.with()` where relationships exist
- [ ] Added to `ServiceStorageContainer` in Application+Services.swift
- [ ] Application extension property added
- [ ] `Application.Repositories` extension added
- [ ] Initialized in `Application-Setup.swift`
- [ ] Mock created for testing
- [ ] Uses `\.$field` syntax for Fluent filters

## Codebase Examples

- `Sources/App/Modules/Auth/Repositories/RefreshTokenRepository.swift` - Full implementation
- `Sources/App/Modules/Waitlist/Repositories/WaitlistRepository.swift` - Simple CRUD
- `Sources/App/Common/Framework/Repository.swift` - Base protocols
- `Sources/App/Services/Repositories/Application+Repository.swift` - Application.Repositories

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Forgetting eager loading | Use `.with(\.$relation)` to prevent N+1 queries |
| Not handling nil ID | Guard against nil: `guard let id = id else { return nil }` |
| Direct Model queries in controllers | Always use repository methods |
| Missing `for(_ req:)` | Inherited from `DatabaseRepository` - don't override unless needed |
| Wrong filter syntax | Use `\.$field` not `\.field` for Fluent key paths |
| Forgetting delete cascade | Check migration for proper foreign key behavior |
