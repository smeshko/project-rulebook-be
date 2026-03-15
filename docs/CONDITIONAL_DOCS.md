---
title: Conditional Documentation Guide
description: Find documentation based on your current task
author: Claude
date: 2026-01-23
---

# Conditional Documentation Guide

This guide helps you find relevant documentation based on what you're working on.

## Instructions

- Review the task you need to perform
- Check the conditions below
- Read the relevant documentation before proceeding
- Only read documentation if conditions match your task

## Documentation Map

- docs/architecture/README.md
  - Conditions:
    - When learning the codebase
    - When understanding architecture overview

- docs/architecture/architectural-vision.md
  - Conditions:
    - When learning the codebase
    - When understanding design principles

- docs/architecture/technical-architecture.md
  - Conditions:
    - When making architectural decisions
    - When understanding service layer patterns
    - When understanding module architecture
    - When learning the codebase

- docs/architecture/ADRs/
  - Conditions:
    - When planning significant changes
    - When reviewing past architectural decisions

- docs/architecture/future-architecture-decisions.md
  - Conditions:
    - When planning significant changes
    - When understanding planned architectural changes

- docs/development/README.md
  - Conditions:
    - When setting up the development environment
    - When debugging issues
    - When onboarding to the project

- docs/development/getting-started.md
  - Conditions:
    - When setting up the development environment for the first time
    - When onboarding new team members

- docs/development/deployment.md
  - Conditions:
    - When deploying to staging or production

- docs/development/vscode-setup.md
  - Conditions:
    - When setting up VS Code for development

- docs/development/xcode-setup.md
  - Conditions:
    - When setting up Xcode for development

- docs/templates/service-creation.md
  - Conditions:
    - When adding external API integration
    - When adding shared functionality

- docs/templates/error-creation.md
  - Conditions:
    - When creating custom error types
    - When adding external API integration

- docs/templates/repository-creation.md
  - Conditions:
    - When adding database access for a new entity

- docs/templates/model-creation.md
  - Conditions:
    - When adding database access for a new entity
    - When adding or modifying database schema

- docs/templates/migration-creation.md
  - Conditions:
    - When adding database access for a new entity
    - When adding or modifying database schema

- docs/templates/controller-creation.md
  - Conditions:
    - When adding new HTTP endpoints
    - When modifying existing routes

- docs/templates/router-creation.md
  - Conditions:
    - When adding new HTTP endpoints
    - When modifying existing routes

- docs/templates/module-creation.md
  - Conditions:
    - When adding a new feature domain

- docs/reference/api-contracts.md
  - Conditions:
    - When adding new HTTP endpoints
    - When modifying existing routes
    - When changing existing API behavior

- docs/reference/data-models.md
  - Conditions:
    - When adding or modifying database schema
    - When understanding existing data structures

- docs/reference/source-tree.md
  - Conditions:
    - When learning the codebase
    - When understanding project structure

- docs/testing/README.md
  - Conditions:
    - When writing new tests
    - When debugging issues
    - When running tests

- docs/testing/standards-and-patterns.md
  - Conditions:
    - When writing new tests
    - When understanding testing best practices

- docs/testing/performance.md
  - Conditions:
    - When writing performance tests
    - When optimizing application performance

- docs/product/prd.md
  - Conditions:
    - When planning significant changes
    - When understanding product requirements

- docs/features/remote-config.md
  - Conditions:
    - When implementing feature flags or remote configuration
    - When creating public endpoints for app configuration
    - When adding admin-only CRUD endpoints with authentication
    - When implementing Redis caching with PostgreSQL fallback
    - When working with typed configuration values

- docs/DOCUMENTATION_STANDARDS.md
  - Conditions:
    - When writing or updating documentation
    - When creating new documentation files

- docs/features/receipts-module.md
  - Conditions:
    - When implementing in-app purchase verification for the Receipts module
    - When adding transaction storage or receipt validation endpoints
    - When enforcing idempotency for store transaction records
    - When working with platform-specific enums (ios/android) in database models

- docs/features/app-store-validation.md
  - Conditions:
    - When implementing App Store receipt or transaction validation in the Receipts module
    - When configuring Apple App Store credentials or environment variables
    - When adding new platform-specific purchase verification services
    - When troubleshooting App Store JWS signature verification failures
    - When upgrading the app-store-server-library-swift dependency

- docs/features/play-store-validation.md
  - Conditions:
    - When implementing Play Store purchase verification in the Receipts module
    - When configuring Google Play service account credentials or environment variables
    - When adding new platform-specific purchase verification services for Android
    - When troubleshooting Google OAuth2 service account authentication issues
    - When working with Google Play Developer API token exchange flow

- docs/features/receipt-validation-endpoint.md
  - Conditions:
    - When implementing or modifying the receipt validation endpoint in the Receipts module
    - When adding new in-app purchase product IDs or credit tiers
    - When modifying platform-specific validation branching logic (iOS/Android)
    - When working with custom HTTP status codes in Vapor controller responses
    - When troubleshooting receipt validation error responses (400/403)

- docs/features/receipt-hash-app-identity.md
  - Conditions:
    - When implementing receipt hash-based rate limiting or deduplication in the Receipts module
    - When adding app identity validation for new store platforms
    - When troubleshooting `invalid_app_identity` 403 errors from the receipt validation endpoint
    - When modifying bundle ID or package name environment variable configuration
