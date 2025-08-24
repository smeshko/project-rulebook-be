# OpenAI Service Tests Enablement Plan

## Current Status
The OpenAI service tests have several disabled tests due to HTTP client initialization issues. One test (`successfulGeneration`) works correctly, demonstrating the proper pattern.

## Working Pattern Analysis
The working test follows this pattern:
```swift
let testWorld = try await TestWorld()
let app = testWorld.app
let mockClient = MockHTTPClient(eventLoop: app.eventLoopGroup.next())
app.clients.use { _ in mockClient }
mockClient.mockResponse = MockHTTPResponse.success(expectedResponse)
```

## Disabled Tests to Enable

### 1. `rateLimitWithRetry()` - Line 65
- **Purpose**: Test retry logic on rate limits
- **Mock Setup**: Should simulate HTTP 429 response, then success
- **Expected Behavior**: Service should retry and eventually succeed

### 2. `unexpectedError()` - Line 74  
- **Purpose**: Test handling of unexpected HTTP errors
- **Mock Setup**: Should simulate HTTP 500 error
- **Expected Behavior**: Service should throw appropriate error

### 3. `invalidAPIKey()` - Line 84
- **Purpose**: Test handling of invalid API key (401 error)  
- **Mock Setup**: Should simulate HTTP 401 response
- **Expected Behavior**: Service should throw authentication error

### 4. `emptyResponse()` - Line 95
- **Purpose**: Test handling of empty response bodies
- **Mock Setup**: Should return empty/null response
- **Expected Behavior**: Service should handle gracefully or throw appropriate error

### 5. `invalidJSONResponse()` - Line 105
- **Purpose**: Test handling of malformed JSON responses
- **Mock Setup**: Should return invalid JSON string
- **Expected Behavior**: Service should throw JSON parsing error

### 6. `optimizedGenerationWithCustomParameters()` - Line 115
- **Purpose**: Test service with custom OpenAI parameters
- **Mock Setup**: Should verify request parameters and return success
- **Expected Behavior**: Service should pass through custom parameters correctly

## Implementation Strategy

### Phase 1: Identify Root Cause
1. **Analyze Working Test**: Understand why `successfulGeneration` works
2. **Compare with Broken Tests**: Identify specific differences
3. **Check MockHTTPClient**: Verify it supports all needed response types

### Phase 2: Fix Test Infrastructure
1. **Enhance MockHTTPClient**: Add support for error responses, empty responses, invalid JSON
2. **Add Response Helpers**: Create factory methods for common error scenarios
3. **Verify Cleanup**: Ensure proper app shutdown in all scenarios

### Phase 3: Enable Tests One by One
1. **Start with Simple Cases**: Enable `emptyResponse` and `invalidJSONResponse` first
2. **Add Error Scenarios**: Enable `unexpectedError` and `invalidAPIKey`  
3. **Complex Logic**: Enable `rateLimitWithRetry` and `optimizedGeneration`
4. **Verify Each**: Test each individually before moving to next

### Phase 4: Migration to IsolatedTestWorld
1. **Update Pattern**: Convert from `TestWorld()` to `IsolatedTestWorld()`
2. **Maintain Mock Setup**: Ensure HTTP client mocking still works
3. **Verify Isolation**: Confirm tests can run concurrently

## Required Infrastructure Changes

### MockHTTPClient Enhancements
```swift
// Add support for error responses
mockClient.mockResponse = MockHTTPResponse.error(status: .tooManyRequests)

// Add support for empty responses  
mockClient.mockResponse = MockHTTPResponse.empty()

// Add support for invalid JSON
mockClient.mockResponse = MockHTTPResponse.invalidJSON("not valid json")

// Add support for retry scenarios
mockClient.mockResponses = [
    MockHTTPResponse.error(status: .tooManyRequests),
    MockHTTPResponse.success(expectedResponse)
]
```

### Test Structure Template
```swift
@Test("Test description")
func testName() async throws {
    // Arrange
    let testWorld = try await IsolatedTestWorld()
    let app = testWorld.app
    
    let mockClient = MockHTTPClient(eventLoop: app.eventLoopGroup.next())
    app.clients.use { _ in mockClient }
    
    // Configure specific mock behavior
    mockClient.mockResponse = MockHTTPResponse./*scenario*/
    
    let service = OpenAIService(app: app)
    
    // Act & Assert
    // ... test logic
    
    // No manual cleanup needed with IsolatedTestWorld
}
```

## Success Criteria
- [ ] All 6 disabled tests are enabled and passing
- [ ] Tests use IsolatedTestWorld for proper isolation
- [ ] MockHTTPClient supports all required response scenarios
- [ ] Tests can run concurrently without interference
- [ ] No manual cleanup required (handled by IsolatedTestWorld)

## Risk Assessment
- **Low Risk**: Following existing working pattern
- **Infrastructure Dependent**: Requires MockHTTPClient enhancements
- **Test Isolation**: Must ensure concurrent test execution works properly

## Timeline Estimate
- **Phase 1**: 1-2 hours (analysis and root cause identification)
- **Phase 2**: 2-3 hours (infrastructure enhancements)
- **Phase 3**: 2-4 hours (enabling tests individually)
- **Phase 4**: 1 hour (migration to IsolatedTestWorld)
- **Total**: 6-10 hours