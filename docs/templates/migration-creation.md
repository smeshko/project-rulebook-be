---
title: "Migration Creation Template"
description: "Guide for creating Fluent migrations in project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Migration Creation Template

## When to Use

- Creating new database tables
- Adding/removing columns from existing tables
- Adding constraints (unique, foreign keys, indexes)
- Any schema modification

## Quick Reference

| Component | Description |
|-----------|-------------|
| Location | `Sources/App/Modules/{Module}/Database/Migrations/{Module}Migrations.swift` |
| Protocol | `AsyncMigration` |
| Pattern | Enum namespace with versioned structs |
| Registration | In module's `boot()` method |

## Code Template

### Initial Migration (v1)

Create `Sources/App/Modules/{Module}/Database/Migrations/{Module}Migrations.swift`:

```swift
import Fluent
import Vapor

enum {Module}Migrations {

    // MARK: - v1: Initial Schema

    struct v1: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema({Entity}Model.schema)
                // Primary key
                .id()
                // Required fields
                .field({Entity}Model.FieldKeys.v1.name, .string, .required)
                .field({Entity}Model.FieldKeys.v1.email, .string, .required)
                // Optional fields
                .field({Entity}Model.FieldKeys.v1.description, .string)
                // Boolean with default
                .field({Entity}Model.FieldKeys.v1.isActive, .bool, .required, .custom("DEFAULT true"))
                // Foreign key
                .field({Entity}Model.FieldKeys.v1.userId, .uuid, .required)
                .foreignKey(
                    {Entity}Model.FieldKeys.v1.userId,
                    references: UserAccountModel.schema, .id,
                    onDelete: .cascade
                )
                // Timestamps
                .field({Entity}Model.FieldKeys.v1.createdAt, .datetime)
                .field({Entity}Model.FieldKeys.v1.updatedAt, .datetime)
                .field({Entity}Model.FieldKeys.v1.deletedAt, .datetime)
                // Constraints
                .unique(on: {Entity}Model.FieldKeys.v1.email)
                .create()
        }

        func revert(on database: Database) async throws {
            try await database.schema({Entity}Model.schema).delete()
        }
    }
}
```

### Adding New Version

```swift
enum {Module}Migrations {
    struct v1: AsyncMigration { /* ... */ }

    // MARK: - v2: Add New Field

    struct v2: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema({Entity}Model.schema)
                .field({Entity}Model.FieldKeys.v2.newField, .string)
                .update()
        }

        func revert(on database: Database) async throws {
            try await database.schema({Entity}Model.schema)
                .deleteField({Entity}Model.FieldKeys.v2.newField)
                .update()
        }
    }
}
```

### Register in Module

```swift
struct {Module}Module: ModuleInterface {
    let router = {Module}Router()

    func boot(_ app: Application) throws {
        // Register migrations in order
        app.migrations.add({Module}Migrations.v1())
        app.migrations.add({Module}Migrations.v2())  // Add new versions

        try router.boot(routes: app.routes)
    }
}
```

## Field Types Reference

| Swift Type | Fluent Type | Notes |
|------------|-------------|-------|
| `String` | `.string` | Variable length text |
| `String` | `.string(Database.FieldLength)` | Fixed max length |
| `Int` | `.int` | 32-bit integer |
| `Int64` | `.int64` | 64-bit integer |
| `Double` | `.double` | Floating point |
| `Bool` | `.bool` | Boolean |
| `UUID` | `.uuid` | UUID |
| `Date` | `.datetime` | Timestamp |
| `Data` | `.data` | Binary data |
| `[String]` | `.array(of: .string)` | Array |
| `Enum` | `.string` | Store as string |
| `JSON` | `.json` | JSON blob |

## Constraint Patterns

### Unique Constraint

```swift
// Single field
.unique(on: {Entity}Model.FieldKeys.v1.email)

// Composite unique
.unique(on: {Entity}Model.FieldKeys.v1.userId, {Entity}Model.FieldKeys.v1.itemId)
```

### Foreign Key

```swift
.foreignKey(
    {Entity}Model.FieldKeys.v1.userId,
    references: UserAccountModel.schema, .id,
    onDelete: .cascade    // or .setNull, .restrict, .noAction
)
```

### Index (Non-Unique)

```swift
// Single field index
.index(on: {Entity}Model.FieldKeys.v1.status)

// Composite index
.index(on: {Entity}Model.FieldKeys.v1.userId, {Entity}Model.FieldKeys.v1.createdAt)
```

### Required vs Optional

```swift
// Required field (NOT NULL)
.field({Entity}Model.FieldKeys.v1.name, .string, .required)

// Optional field (allows NULL)
.field({Entity}Model.FieldKeys.v1.description, .string)
```

### Default Values

```swift
// Boolean default
.field({Entity}Model.FieldKeys.v1.isActive, .bool, .required, .custom("DEFAULT true"))

// Timestamp default
.field({Entity}Model.FieldKeys.v1.createdAt, .datetime, .custom("DEFAULT CURRENT_TIMESTAMP"))
```

## Update Migration Patterns

### Add Column

```swift
struct v2: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .field({Entity}Model.FieldKeys.v2.newField, .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .deleteField({Entity}Model.FieldKeys.v2.newField)
            .update()
    }
}
```

### Add Constraint

```swift
struct v3: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .unique(on: {Entity}Model.FieldKeys.v1.email)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .deleteUnique(on: {Entity}Model.FieldKeys.v1.email)
            .update()
    }
}
```

### Rename Column

```swift
struct v4: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .updateField(.custom("RENAME COLUMN old_name TO new_name"))
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema({Entity}Model.schema)
            .updateField(.custom("RENAME COLUMN new_name TO old_name"))
            .update()
    }
}
```

## FieldKeys Versioning

When adding fields in new migrations, extend FieldKeys:

```swift
extension {Entity}Model {
    struct FieldKeys {
        struct v1 {
            static var name: FieldKey { "name" }
            static var email: FieldKey { "email" }
            static var createdAt: FieldKey { "created_at" }
        }
        struct v2 {
            static var newField: FieldKey { "new_field" }
        }
    }
}
```

## Implementation Checklist

- [ ] Enum namespace pattern (`{Module}Migrations`)
- [ ] Versioned struct (`v1`, `v2`, etc.)
- [ ] Conforms to `AsyncMigration`
- [ ] `prepare` creates/updates schema
- [ ] `revert` reverses changes exactly
- [ ] Uses `{Entity}Model.FieldKeys` for field names
- [ ] Uses `{Entity}Model.schema` for table name
- [ ] Foreign keys with appropriate cascade rules
- [ ] Unique constraints for identifiers
- [ ] Timestamps included (createdAt, updatedAt, deletedAt)
- [ ] Migration registered in module's `boot()`
- [ ] FieldKeys extended for new versions

## Codebase Examples

- `Sources/App/Modules/Auth/Database/Migrations/AuthMigrations.swift` - Multiple tables
- `Sources/App/Modules/User/Database/Migrations/UserMigrations.swift` - User with constraints
- `Sources/App/Modules/Waitlist/Database/Migrations/WaitlistMigrations.swift` - Simple table

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Non-reversible migrations | Always implement `revert` to match `prepare` |
| Missing cascade rules | Foreign keys need explicit `onDelete` behavior |
| Wrong field order | ID first, then fields, then timestamps |
| Forgetting unique constraints | Tokens and emails usually need them |
| Not versioning FieldKeys | Use `FieldKeys.v1`, `FieldKeys.v2` for each migration |
| Modifying existing migrations | Create new version instead of changing v1 |
| Missing `.required` | Required fields need explicit `.required` modifier |
