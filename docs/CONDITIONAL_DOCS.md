---
title: "Conditional Documentation Guide"
description: "Find relevant documentation based on your task"
author: Claude
date: 2026-01-23
---

# Conditional Documentation Guide

Find the right documentation based on what you're working on.

## How to Use

1. Identify your task type below
2. Read the listed documents before starting
3. Only read documentation relevant to your task

---

## Creating New Components

### Creating a Service

**Read when:** Adding external API integration or shared functionality

- `docs/templates/service-creation.md` - Step-by-step guide
- `docs/templates/error-creation.md` - Custom error types
- `docs/architecture/technical-architecture.md` - Service layer patterns

### Creating a Repository

**Read when:** Adding database access for a new entity

- `docs/templates/repository-creation.md` - Repository patterns
- `docs/templates/model-creation.md` - Database model structure
- `docs/templates/migration-creation.md` - Schema changes

### Creating a Controller

**Read when:** Adding new HTTP endpoints

- `docs/templates/controller-creation.md` - Controller patterns
- `docs/templates/router-creation.md` - Route definitions
- `docs/reference/api-contracts.md` - API contracts and versioning

### Creating a Module

**Read when:** Adding a new feature domain

- `docs/templates/module-creation.md` - Module structure
- `docs/architecture/technical-architecture.md` - Module architecture
- All other templates (service, repository, controller, etc.)

### Creating Database Changes

**Read when:** Adding or modifying database schema

- `docs/templates/migration-creation.md` - Migration patterns
- `docs/templates/model-creation.md` - Model structure
- `docs/reference/data-models.md` - Existing data models

---

## Working with Existing Code

### Modifying API Endpoints

**Read when:** Changing existing routes or adding new ones

- `docs/reference/api-contracts.md` - API contracts and versioning
- `docs/templates/router-creation.md` - Route patterns
- `docs/templates/controller-creation.md` - Controller patterns

### Adding Tests

**Read when:** Writing new tests

- `docs/testing/README.md` - Testing infrastructure
- `docs/testing/standards-and-patterns.md` - Testing best practices
- `docs/testing/performance.md` - Performance testing

### Debugging Issues

**Read when:** Troubleshooting problems

- `docs/development/README.md` - Development environment
- `docs/testing/README.md` - Running tests
- Root `README.md` - Troubleshooting section

---

## Architecture & Design

### Understanding the System

**Read when:** Learning the codebase

- `docs/architecture/README.md` - Architecture index
- `docs/architecture/architectural-vision.md` - Design principles
- `docs/architecture/technical-architecture.md` - Technical details
- `docs/reference/source-tree.md` - Project structure

### Making Architectural Decisions

**Read when:** Planning significant changes

- `docs/architecture/ADRs/` - Past decisions
- `docs/architecture/future-architecture-decisions.md` - Planned changes
- `docs/product/prd.md` - Product requirements

---

## Deployment & Operations

### Deploying Changes

**Read when:** Deploying to staging or production

- `docs/development/deployment.md` - Deployment procedures

### Setting Up Development

**Read when:** Initial setup or environment issues

- `docs/development/README.md` - Setup overview
- `docs/development/getting-started.md` - Detailed setup
- `docs/development/vscode-setup.md` or `docs/development/xcode-setup.md` - IDE setup

---

## Quick Reference by File Type

| When creating... | Read these templates |
|-----------------|---------------------|
| `*Module.swift` | module-creation.md |
| `*Router.swift` | router-creation.md |
| `*Controller.swift` | controller-creation.md |
| `*Repository.swift` | repository-creation.md |
| `*Model.swift` | model-creation.md |
| `*Migrations.swift` | migration-creation.md |
| `*Service.swift` | service-creation.md |
| `*Error.swift` | error-creation.md |

---

## Feature Documentation

### Remote Configuration

**Read when:** Working with feature flags or app settings

- `docs/features/remote-config.md` - Complete feature documentation
  - When implementing caching for the remote config module
  - When adding new admin endpoints to the remote config module
  - When modifying the public config endpoint behavior
  - When troubleshooting cache invalidation for remote config
  - When extending value types or categories for remote configuration

---

## Critical Documents

Always be aware of:

- `docs/architecture/technical-architecture.md` - Architecture, patterns, and rules
- `docs/DOCUMENTATION_STANDARDS.md` - Documentation requirements
