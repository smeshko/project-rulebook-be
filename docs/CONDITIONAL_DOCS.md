# Conditional Documentation Guide

This guide helps you find relevant documentation based on what you're working on.

## Instructions

- Review the task you need to perform
- Check the conditions below
- Read the relevant documentation before proceeding
- Only read documentation if conditions match your task

## Documentation Map

- docs/features/api-versioning.md
  - Conditions:
    - When adding new API endpoints
    - When creating new modules with public routes
    - When updating route definitions in router files
    - When troubleshooting mobile app integration issues
    - When planning breaking API changes
    - When writing integration tests for API endpoints

- docs/features/remote-config.md
  - Conditions:
    - When implementing feature flags or remote configuration
    - When adding public endpoints that don't require authentication
    - When adding admin-only endpoints to an existing module
    - When implementing Redis caching with write-through invalidation
    - When modifying the RemoteConfig module
