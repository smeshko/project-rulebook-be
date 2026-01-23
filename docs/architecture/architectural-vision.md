---
title: "Architectural Vision & Principles"
description: "Core design philosophy and principles for project-rulebook-be"
author: Claude
date: 2026-01-23
---

# Architectural Vision & Principles

**Project:** Project Rulebook
**Document Type:** Consolidated Architectural Vision
**Version:** 2.0
**Date:** 2025-09-12
**Status:** Active  

## Architectural Vision & Principles

### Vision Statement

**"Build less, but build it better."**

We envision a Vapor application architecture that demonstrates that great software is discovered through strategic subtraction, not addition. The architecture embraces framework conventions, maintains module integrity, prioritizes developer experience, and achieves power through simplicity rather than clever complexity.

## Core Philosophy: Elegant Simplicity

Elegant simplicity is not about building less functionality—it's about achieving more with less complexity. This philosophy permeates every architectural decision through a mature understanding that the best code is often the code we choose not to write.

### The Journey to Simplicity

Our architectural evolution represents a philosophical shift from "impressive complexity" to "strategic simplicity." Through continuous refinement and strategic deletion, we've discovered that:

- **Complexity is easy; simplicity is hard**
- **Framework conventions exist for good reasons**
- **Great architecture reveals itself through subtraction**
- **The courage to delete working code is a sign of maturity**

## Five Fundamental Principles

### 1. Contextual Cohesion

Everything related to a feature lives together within its module boundary. A module represents a complete vertical slice of functionality—controllers, repositories, models, and database migrations all coexist within their natural context.

```text
Sources/App/Modules/[Module]/
├── [Module]Module.swift    # Registration & configuration
├── [Module]Router.swift    # Route definitions
├── Controllers/            # HTTP endpoints with business logic
├── Repositories/           # Data access abstraction
├── Models/                 # Domain entities & DTOs
└── Database/               # Migrations & database models
```

**Rationale:** When everything related lives together, developers can understand and modify features without hunting across artificial boundaries.

### 2. Progressive Disclosure

The architecture reveals complexity only when absolutely necessary:

- **Simple operations remain simple** - No unnecessary abstractions for basic CRUD
- **Complex operations are possible** - But clearly bounded and justified
- **Cognitive load increases incrementally** - Never all at once
- **Power without penalty** - Advanced features don't complicate simple ones

**Rationale:** Developers should pay complexity costs only when they need complex features.

### 3. Framework Harmony

We work WITH Vapor's conventions, not against them:

- **Use Vapor's middleware pipeline** over custom AOP systems
- **Leverage Vapor's dependency injection** patterns consistently
- **Follow established directory structures** that Vapor developers expect
- **Embrace async/await** throughout the stack without custom wrappers

**Rationale:** Fighting the framework creates technical debt. Embracing it reduces cognitive overhead and improves maintainability.

### 4. The Three-Strike Rule

Don't create abstractions until the third occurrence:

1. **First time:** Write the code inline
2. **Second time:** Copy and adapt (yes, duplication is okay temporarily)
3. **Third time:** Now you understand the pattern—create the abstraction

**Rationale:** Premature abstraction is worse than temporary duplication. Real patterns emerge through experience, not speculation.

### 5. Standard Library First

Before creating any utility or extension:

1. ✅ **Check Swift standard library** - It probably exists
2. ✅ **Check Vapor framework** - They likely solved it
3. ✅ **Verify the problem** - Are you solving the right thing?
4. ✅ **Only then consider custom** - With clear justification

**Rationale:** Custom utilities increase maintenance burden. Standard solutions have better documentation, testing, and community support.

## Decision Framework

For any architectural decision, apply these tests in order:

### 1. Simplicity Test
- Is this the simplest solution that could possibly work?
- Am I adding complexity to solve a real problem or an imaginary one?
- Would a junior developer understand this immediately?

### 2. Convention Test
- Does this follow established Vapor patterns?
- Would an experienced Vapor developer find this surprising?
- Am I creating a "better" way or just a "different" way?

### 3. Maintenance Test
- Will this be easy to modify in 6 months?
- Does this reduce or increase cognitive load?
- Can I explain this decision in one sentence?

### 4. Deletion Test
- Can I achieve the goal without adding this?
- What happens if I just don't build this feature?
- Would removing this break core functionality?

## Anti-Patterns to Avoid

### 🚩 The Premature Abstraction
**Symptom:** Creating complex systems for hypothetical future needs  
**Example:** Building backward compatibility for migrations that never happen  
**Solution:** Apply the Three-Strike Rule rigorously

### 🚩 The Utility Extension Addiction
**Symptom:** Wrapping standard library functions with custom extensions  
**Example:** `TimeInterval.hours(2)` instead of `2 * 3600`  
**Solution:** Use standard library directly unless extension adds significant value

### 🚩 The Framework Fighter
**Symptom:** Building custom solutions when framework provides them  
**Example:** Custom AOP system instead of Vapor middleware  
**Solution:** Learn and embrace framework conventions first

### 🚩 The Module Boundary Violator
**Symptom:** Separating related concerns across multiple directories  
**Example:** Use cases in separate top-level directory from their modules  
**Solution:** Maintain complete vertical slices within modules

### 🚩 The Clever Complexity
**Symptom:** Impressive but hard-to-understand solutions  
**Example:** 5-component aspect orchestration system  
**Solution:** Choose boring, predictable patterns over clever ones

## Architectural Evolution

### Current Architecture

Our architecture prioritizes simplicity and framework harmony over layered abstractions:

**Architecture Pattern: Controller-Centric Design**
- **Controllers:** HTTP handling + business logic in one place
- **Services:** External integrations (LLM, Email, Cache)
- **Repositories:** Data access abstraction for testability
- **No separate use case layer** - business logic stays in controllers

**Why Controller-Centric?**
- Reduces indirection and cognitive overhead
- Follows Vapor conventions naturally
- Makes request flow easy to trace and debug
- Keeps simple operations simple

### Continuous Refinement Process

Architecture evolves through:
1. **Recognition:** Identifying complexity that doesn't add value
2. **Validation:** Ensuring functionality preservation
3. **Migration:** Careful refactoring with test coverage
4. **Deletion:** Strategic removal of unnecessary code
5. **Documentation:** Recording decisions and rationale

## Practical Implementation Guidelines

### Service Access Pattern
```swift
// Access services via request extensions
func handleRequest(_ req: Request) async throws -> Response {
    let llm = req.services.llm
    let user = try await req.repositories.users.find(id: userId)
    // Business logic here in controller
}
```

### Controller Pattern
```swift
// Controllers contain HTTP handling AND business logic
struct AuthController {
    func signUp(_ req: Request) async throws -> Auth.SignUp.Response {
        // Validation, business logic, persistence all here
        let user = try await req.repositories.users.create(newUser)
        try await req.services.email.sendVerification(to: user.email)
        return Auth.SignUp.Response(user: user, token: token)
    }
}
```

### Module Organization
- **Complete vertical slices** within module boundaries
- **Business logic in controllers** - no separate use case layer
- **Clear interfaces** between modules via protocols
- **Minimal coupling** through property-based DI

## Success Metrics

### Developer Experience
- **Onboarding time:** New developers productive within 1 day
- **Feature velocity:** Predictable development timeframes
- **Bug resolution:** Issues traced and fixed rapidly

### Code Quality
- **Cyclomatic complexity:** Consistently low
- **Test coverage:** High for critical paths
- **Documentation debt:** Self-documenting code

### Maintenance
- **Refactoring confidence:** Changes without fear
- **Technical debt:** Declining through simplification
- **Knowledge transfer:** Easy to explain and understand

## Future Direction

### Immediate Priorities
- Continue identifying simplification opportunities
- Document architectural decisions in ADRs
- Maintain framework alignment during upgrades

### Long-term Vision
- Self-documenting architecture requiring minimal explanation
- Zero cognitive overhead for standard operations
- Architecture that actively guides developers toward good decisions

## Conclusion

This architectural vision represents a mature understanding that great software emerges through thoughtful simplification. By embracing elegant simplicity, we create systems that:

- **Serve developers** by getting out of their way
- **Serve businesses** by enabling rapid, confident changes
- **Serve users** by maintaining reliability and performance

The path forward is clear: Continue building less, but building it better. Every line of code we choose not to write is a future bug we don't have to fix, a concept we don't have to explain, and complexity we don't have to maintain.

---

**Guiding Principle:** When in doubt, choose the simpler solution. You can always add complexity later if truly needed, but you can rarely remove it once it's embedded in your system.