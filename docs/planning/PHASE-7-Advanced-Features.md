# Phase 7: Advanced Features

**Status**: 📋 PLANNED  
**Timeline**: 2 weeks  
**Priority**: P4 (Low-Medium)  
**Prerequisites**: Phase 6 (Observability & Documentation)

## 🎯 Objective

Implement enterprise-grade features including transaction management with Unit of Work pattern, background job processing with queues, and frontend architecture improvements for better user experience.

## 📋 Task 7.1: Transaction Management

**Timeline**: 3-4 days | **Complexity**: High

### Current Issues
- No transaction boundary management
- Potential data inconsistency in multi-step operations
- No compensation logic for failures
- Missing distributed transaction support

### Implementation Plan

#### Step 1: Unit of Work Pattern
```swift
protocol UnitOfWork {
    func begin() async throws
    func commit() async throws
    func rollback() async throws
    func register<T: Model>(_ entity: T, operation: Operation)
}

enum Operation {
    case insert
    case update
    case delete
}

final class DatabaseUnitOfWork: UnitOfWork {
    private let database: Database
    private var operations: [(any Model, Operation)] = []
    private var transaction: DatabaseTransaction?
    
    init(database: Database) {
        self.database = database
    }
    
    func begin() async throws {
        transaction = try await database.transaction { db in
            // Transaction will be committed or rolled back
            return db
        }
    }
    
    func register<T: Model>(_ entity: T, operation: Operation) {
        operations.append((entity, operation))
    }
    
    func commit() async throws {
        guard let transaction = transaction else {
            throw UnitOfWorkError.noActiveTransaction
        }
        
        for (entity, operation) in operations {
            switch operation {
            case .insert:
                try await entity.create(on: transaction)
            case .update:
                try await entity.update(on: transaction)
            case .delete:
                try await entity.delete(on: transaction)
            }
        }
        
        operations.removeAll()
    }
    
    func rollback() async throws {
        operations.removeAll()
        transaction = nil
    }
}
```

#### Step 2: Saga Pattern for Distributed Transactions
```swift
protocol Saga {
    associatedtype Context
    
    func execute(context: Context) async throws
    func compensate(context: Context) async throws
}

struct SagaOrchestrator {
    private var steps: [any Saga] = []
    private var executedSteps: [any Saga] = []
    
    mutating func addStep<S: Saga>(_ step: S) {
        steps.append(step)
    }
    
    func execute<Context>(context: Context) async throws {
        for step in steps {
            do {
                try await step.execute(context: context)
                executedSteps.append(step)
            } catch {
                // Compensate in reverse order
                for executedStep in executedSteps.reversed() {
                    try? await executedStep.compensate(context: context)
                }
                throw error
            }
        }
    }
}

// Example saga for user registration
struct UserRegistrationSaga: Saga {
    typealias Context = UserRegistrationContext
    
    let createUserStep = CreateUserStep()
    let sendEmailStep = SendWelcomeEmailStep()
    let createTokenStep = CreateTokenStep()
    
    func execute(context: Context) async throws {
        var orchestrator = SagaOrchestrator()
        orchestrator.addStep(createUserStep)
        orchestrator.addStep(sendEmailStep)
        orchestrator.addStep(createTokenStep)
        try await orchestrator.execute(context: context)
    }
    
    func compensate(context: Context) async throws {
        // Cleanup logic
    }
}
```

#### Step 3: Optimistic Locking
```swift
protocol Versioned: Model {
    var version: Int { get set }
}

extension Versioned {
    func updateWithVersion(on db: Database, update: (Self) -> Void) async throws {
        let currentVersion = self.version
        update(self)
        self.version += 1
        
        let affected = try await Self.query(on: db)
            .filter(\._$id == self.id!)
            .filter(\.$version == currentVersion)
            .update()
        
        if affected == 0 {
            throw TransactionError.optimisticLockFailure
        }
    }
}
```

#### Step 4: Event Sourcing (Optional)
```swift
protocol DomainEvent: Codable {
    var aggregateID: UUID { get }
    var timestamp: Date { get }
    var version: Int { get }
}

final class EventStore {
    func append<E: DomainEvent>(_ event: E) async throws {
        let eventData = try JSONEncoder().encode(event)
        let eventRecord = EventRecord(
            aggregateID: event.aggregateID,
            eventType: String(describing: type(of: event)),
            eventData: eventData,
            version: event.version,
            timestamp: event.timestamp
        )
        try await eventRecord.save(on: database)
    }
    
    func getEvents(for aggregateID: UUID) async throws -> [any DomainEvent] {
        let records = try await EventRecord.query(on: database)
            .filter(\.$aggregateID == aggregateID)
            .sort(\.$version)
            .all()
        
        return try records.compactMap { record in
            // Deserialize based on eventType
            deserializeEvent(record)
        }
    }
}
```

### Success Criteria
- ✅ Unit of Work pattern implemented
- ✅ Saga pattern for complex flows
- ✅ Optimistic locking prevents conflicts
- ✅ Transaction rollback works correctly
- ✅ Data consistency maintained

---

## 📋 Task 7.2: Background Job Processing

**Timeline**: 3-4 days | **Complexity**: Medium

### Current Issues
- No async job processing
- Long-running tasks block requests
- No retry mechanism for failures
- Missing job scheduling capability

### Implementation Plan

#### Step 1: Integrate Vapor Queues
```swift
// Package.swift
.package(url: "https://github.com/vapor/queues.git", from: "1.0.0")
.package(url: "https://github.com/vapor/queues-redis-driver.git", from: "1.0.0")

// Configuration
import Queues
import QueuesRedisDriver

extension Application {
    func configureQueues() throws {
        // Use Redis as queue backend
        try queues.use(.redis(url: configuration.redis.url))
        
        // Register jobs
        queues.add(EmailJob())
        queues.add(RulesGenerationJob())
        queues.add(CleanupJob())
        
        // Schedule recurring jobs
        queues.schedule(CleanupJob())
            .daily()
            .at(2, 0) // 2:00 AM
        
        // Start queue workers in production
        if environment.isRelease {
            try queues.startInProcessJobs(on: .default)
            try queues.startScheduledJobs()
        }
    }
}
```

#### Step 2: Define Job Types
```swift
struct EmailJob: AsyncJob {
    typealias Payload = EmailPayload
    
    func dequeue(_ context: QueueContext, _ payload: EmailPayload) async throws {
        let emailService = context.application.services.email.service
        
        try await emailService.send(
            to: payload.recipient,
            subject: payload.subject,
            body: payload.body
        )
        
        context.logger.info("Email sent to \(payload.recipient)")
    }
    
    func error(_ context: QueueContext, _ error: Error, _ payload: EmailPayload) async throws {
        context.logger.error("Email job failed: \(error)")
        
        // Retry logic
        if context.queueName.attemptCount < 3 {
            throw error // Will be retried
        } else {
            // Send to dead letter queue
            try await context.application.queues.queue(.deadLetter)
                .dispatch(DeadLetterJob.self, payload)
        }
    }
}

struct RulesGenerationJob: AsyncJob {
    typealias Payload = RulesGenerationPayload
    
    func dequeue(_ context: QueueContext, _ payload: RulesGenerationPayload) async throws {
        let llmService = context.application.services.llm.service
        let cacheService = context.application.services.cache.service
        
        // Generate rules
        let rules = try await llmService.generateRules(for: payload.gameTitle)
        
        // Cache the result
        let cacheKey = "rules:\(payload.gameTitle.lowercased())"
        try await cacheService.set(cacheKey, value: rules, ttl: 86400) // 24 hours
        
        // Notify user if needed
        if let userID = payload.userID {
            try await notifyUser(userID, rules: rules)
        }
    }
}
```

#### Step 3: Implement Retry Logic
```swift
struct RetryableJob: AsyncJob {
    typealias Payload = RetryablePayload
    
    func dequeue(_ context: QueueContext, _ payload: Payload) async throws {
        let maxRetries = payload.maxRetries ?? 3
        let currentAttempt = context.queueName.attemptCount
        
        do {
            try await performWork(payload)
        } catch {
            if currentAttempt < maxRetries {
                // Exponential backoff
                let delay = pow(2.0, Double(currentAttempt)) * 60 // seconds
                
                context.logger.warning("Job failed, retrying in \(delay) seconds")
                
                // Re-queue with delay
                try await context.application.queues.queue(.default)
                    .dispatch(Self.self, payload, delayUntil: Date().addingTimeInterval(delay))
            } else {
                // Max retries reached
                context.logger.error("Job failed after \(maxRetries) attempts")
                
                // Move to dead letter queue
                try await context.application.queues.queue(.deadLetter)
                    .dispatch(DeadLetterJob.self, DeadLetterPayload(
                        originalJob: String(describing: Self.self),
                        payload: payload,
                        error: error.localizedDescription
                    ))
            }
        }
    }
}
```

#### Step 4: Job Monitoring
```swift
struct JobMonitor {
    let metrics: MetricsService
    let logger: Logger
    
    func trackJobExecution<J: AsyncJob>(_ job: J.Type, duration: TimeInterval, success: Bool) {
        let jobName = String(describing: job)
        
        metrics.jobExecutionDuration.observe(duration, [
            ("job", jobName),
            ("status", success ? "success" : "failure")
        ])
        
        metrics.jobExecutionCounter.inc([
            ("job", jobName),
            ("status", success ? "success" : "failure")
        ])
        
        if !success {
            logger.error("Job failed", metadata: [
                "job": .string(jobName),
                "duration": .string("\(duration)s")
            ])
        }
    }
    
    func getQueueDepth() async throws -> [String: Int] {
        var depths: [String: Int] = [:]
        
        for queue in [Queue.default, .high, .low, .deadLetter] {
            depths[queue.name] = try await redis.llen(queue.redisKey)
        }
        
        return depths
    }
}
```

### Success Criteria
- ✅ Queue system operational
- ✅ Jobs process asynchronously
- ✅ Retry logic with exponential backoff
- ✅ Dead letter queue for failed jobs
- ✅ Job monitoring dashboard

---

## 📋 Task 7.3: Frontend Architecture Improvements

**Timeline**: 2-3 days | **Complexity**: Low

### Current Issues
- Form validation scattered
- No reusable components
- Template rendering inefficient
- Missing client-side optimizations

### Implementation Plan

#### Step 1: Enhanced Form Framework
```swift
protocol FormField {
    var name: String { get }
    var label: String { get }
    var validators: [Validator] { get }
    var errors: [String] { get set }
    
    func validate(_ value: String?) -> Bool
    func render() -> Node
}

struct TextField: FormField {
    let name: String
    let label: String
    let placeholder: String?
    let validators: [Validator]
    var errors: [String] = []
    
    func validate(_ value: String?) -> Bool {
        errors.removeAll()
        
        for validator in validators {
            if let error = validator.validate(value) {
                errors.append(error)
            }
        }
        
        return errors.isEmpty
    }
    
    func render() -> Node {
        Div {
            Label { label }
                .for(name)
            
            Input()
                .type(.text)
                .name(name)
                .id(name)
                .placeholder(placeholder ?? "")
                .class(errors.isEmpty ? "form-control" : "form-control error")
            
            if !errors.isEmpty {
                Div {
                    errors.map { Text($0) }
                }
                .class("error-messages")
            }
        }
        .class("form-group")
    }
}

struct FormBuilder {
    private var fields: [FormField] = []
    
    mutating func add(_ field: FormField) {
        fields.append(field)
    }
    
    func build() -> Form {
        Form {
            fields.map { $0.render() }
        }
    }
}
```

#### Step 2: Component Library
```swift
// Reusable UI components
struct Card: HTML {
    let title: String
    let content: () -> Node
    
    func render() -> Node {
        Div {
            Div { title }.class("card-header")
            Div { content() }.class("card-body")
        }
        .class("card")
    }
}

struct Alert: HTML {
    enum Style {
        case success, warning, error, info
    }
    
    let message: String
    let style: Style
    
    func render() -> Node {
        Div { message }
            .class("alert alert-\(style)")
            .role("alert")
    }
}

struct Pagination: HTML {
    let currentPage: Int
    let totalPages: Int
    let baseURL: String
    
    func render() -> Node {
        Nav {
            Ul {
                // Previous button
                Li {
                    A { "Previous" }
                        .href("\(baseURL)?page=\(max(1, currentPage - 1))")
                }
                .class(currentPage == 1 ? "disabled" : "")
                
                // Page numbers
                ForEach(1...totalPages) { page in
                    Li {
                        A { "\(page)" }
                            .href("\(baseURL)?page=\(page)")
                    }
                    .class(page == currentPage ? "active" : "")
                }
                
                // Next button
                Li {
                    A { "Next" }
                        .href("\(baseURL)?page=\(min(totalPages, currentPage + 1))")
                }
                .class(currentPage == totalPages ? "disabled" : "")
            }
            .class("pagination")
        }
    }
}
```

#### Step 3: Template Caching
```swift
struct TemplateCache {
    private var cache: [String: String] = [:]
    private let lock = NSLock()
    
    func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }
    
    func set(_ key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = value
    }
    
    func render<T: HTML>(_ component: T, cacheKey: String? = nil) -> String {
        if let key = cacheKey, let cached = get(key) {
            return cached
        }
        
        let rendered = component.render().renderAsString()
        
        if let key = cacheKey {
            set(key, value: rendered)
        }
        
        return rendered
    }
}

// Template middleware for caching
struct TemplateCacheMiddleware: AsyncMiddleware {
    let cache: TemplateCache
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Check if response can be cached
        guard request.method == .GET else {
            return try await next.respond(to: request)
        }
        
        let cacheKey = "template:\(request.url.path)"
        
        // Check cache
        if let cached = cache.get(cacheKey) {
            return Response(
                status: .ok,
                headers: ["Content-Type": "text/html"],
                body: .init(string: cached)
            )
        }
        
        // Generate response
        let response = try await next.respond(to: request)
        
        // Cache if successful HTML response
        if response.status == .ok,
           response.headers.contentType == .html {
            if let body = response.body.string {
                cache.set(cacheKey, value: body)
            }
        }
        
        return response
    }
}
```

#### Step 4: Client-Side Optimizations
```javascript
// Progressive enhancement with minimal JavaScript
class FormValidator {
    constructor(form) {
        this.form = form;
        this.setupValidation();
    }
    
    setupValidation() {
        this.form.addEventListener('submit', (e) => {
            if (!this.validateForm()) {
                e.preventDefault();
            }
        });
        
        // Real-time validation
        this.form.querySelectorAll('input').forEach(input => {
            input.addEventListener('blur', () => this.validateField(input));
        });
    }
    
    validateField(field) {
        const validators = field.dataset.validators?.split(',') || [];
        const errors = [];
        
        validators.forEach(validator => {
            const error = this.runValidator(validator, field.value);
            if (error) errors.push(error);
        });
        
        this.showErrors(field, errors);
        return errors.length === 0;
    }
    
    validateForm() {
        let valid = true;
        this.form.querySelectorAll('input').forEach(input => {
            if (!this.validateField(input)) valid = false;
        });
        return valid;
    }
}

// Lazy loading for images
document.addEventListener('DOMContentLoaded', () => {
    const images = document.querySelectorAll('img[data-src]');
    const imageObserver = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                const img = entry.target;
                img.src = img.dataset.src;
                imageObserver.unobserve(img);
            }
        });
    });
    
    images.forEach(img => imageObserver.observe(img));
});
```

### Success Criteria
- ✅ Form framework reduces code by 40%
- ✅ Component library created
- ✅ Template caching improves performance
- ✅ Client-side validation working
- ✅ Page load time < 1s

---

## 🎯 Advanced Features Goals

### Transaction Management
- **Data Consistency**: 100% maintained
- **Rollback Success**: 100% of failures
- **Saga Completion**: > 95% success rate
- **Lock Conflicts**: < 1% of transactions

### Background Jobs
- **Processing Time**: < 5s average
- **Retry Success**: > 90% within 3 attempts
- **Queue Depth**: < 1000 jobs
- **Dead Letter Rate**: < 0.1%

### Frontend Performance
- **First Paint**: < 500ms
- **Time to Interactive**: < 1s
- **Lighthouse Score**: > 90
- **Form Submission**: < 200ms

## 📊 Implementation Schedule

### Week 1
- **Days 1-2**: Unit of Work implementation
- **Days 3-4**: Saga pattern and compensation
- **Day 5**: Queue system setup

### Week 2
- **Days 1-2**: Job types and retry logic
- **Day 3**: Job monitoring
- **Days 4-5**: Frontend improvements

## 🎯 Definition of Done

### Task 7.1 (Transaction Management)
- [ ] Unit of Work pattern working
- [ ] Saga orchestration tested
- [ ] Optimistic locking prevents conflicts
- [ ] Event sourcing (optional) implemented
- [ ] All transaction tests passing

### Task 7.2 (Background Jobs)
- [ ] Queue system operational
- [ ] All job types implemented
- [ ] Retry logic tested
- [ ] Monitoring dashboard active
- [ ] Performance targets met

### Task 7.3 (Frontend)
- [ ] Form framework complete
- [ ] Component library documented
- [ ] Template caching active
- [ ] Client optimizations working
- [ ] Performance goals achieved

### Overall Phase 7
- [ ] All features integrated
- [ ] Performance benchmarks passed
- [ ] Documentation complete
- [ ] Security review passed
- [ ] Code review completed
- [ ] Merged to main branch

---

*Phase Start: After Phase 6*  
*Estimated Duration: 2 weeks*  
*Next: Production Release*