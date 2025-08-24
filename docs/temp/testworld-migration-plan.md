# TestWorld Migration Plan

## Overview
The legacy `TestWorld` class uses shared repositories and a global application instance, which can cause test interference. All tests should be migrated to use `IsolatedTestWorld` for proper test isolation.

## Current Status
- **Migrated**: 21 test files already using `IsolatedTestWorld()`
- **Remaining**: 4 test files still using `TestWorld()`

## Files to Migrate

### 1. OpenAIServiceTests.swift:12
- **Usage**: Creates app with mock HTTP clients
- **Migration**: Replace `TestWorld()` with `IsolatedTestWorld()`
- **Impact**: Simple replacement, test only needs app instance

### 2. RandomGeneratorTests.swift:11  
- **Usage**: Tests service registry configuration
- **Migration**: Replace `TestWorld()` with `IsolatedTestWorld()`
- **Impact**: Simple replacement, test only needs app.serviceRegistry

### 3. ConfigurationIntegrationTests.swift:28
- **Usage**: Tests application configuration
- **Migration**: Replace `TestWorld()` with `IsolatedTestWorld()`
- **Impact**: Simple replacement, test only needs app.configuration

### 4. AISecurityTests.swift:11
- **Usage**: Tests AI security services  
- **Migration**: Replace `TestWorld()` with `IsolatedTestWorld()`
- **Impact**: Simple replacement, needs service registry access

## Migration Steps

1. **Replace TestWorld() calls**:
   ```swift
   // Before:
   let testWorld = try await TestWorld()
   
   // After:  
   let testWorld = try await IsolatedTestWorld()
   ```

2. **Update property types**:
   ```swift
   // Before:
   let testWorld: TestWorld
   
   // After:
   let testWorld: IsolatedTestWorld
   ```

3. **Verify functionality**: Each test should work identically with IsolatedTestWorld

## Post-Migration Cleanup

Once all tests are migrated:

1. **Delete TestWorld.swift** - No longer needed
2. **Delete SharedTestRepositories** - Functionality replaced by IsolatedTestWorld
3. **Delete SharedTestApplication** - Functionality replaced by IsolatedTestWorld
4. **Remove TestWorldPreConfiguration** - No longer needed

## Benefits of Migration

- **Test Isolation**: Each test suite gets its own app instance and repositories
- **Concurrent Safety**: Test suites can run in parallel without interference  
- **Predictable State**: No shared state contamination between tests
- **Simplified Architecture**: Single test infrastructure pattern across all tests

## Risk Assessment

- **Low Risk**: All remaining tests use simple patterns that work identically with IsolatedTestWorld
- **No Breaking Changes**: IsolatedTestWorld provides same interface as TestWorld
- **Easy Rollback**: Changes are minimal and can be easily reverted if needed