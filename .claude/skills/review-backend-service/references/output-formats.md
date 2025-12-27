# Output Formats

JSON schemas and examples for the backend review report.

## Complete Report Schema

```json
{
  "summary": {
    "plan_file": "string - path to the plan file used",
    "server_command": "string - command used to start server",
    "endpoints_discovered": "number - count of endpoints found",
    "endpoints_tested": "number - count of endpoints tested",
    "passed": "number - count of successful responses (2xx/3xx)",
    "failed": "number - count of failed responses (4xx/5xx/errors)",
    "health_endpoint": "string - health endpoint that responded",
    "startup_time_ms": "number - time for server to become ready",
    "total_test_time_ms": "number - total time for all endpoint tests"
  },
  "discovery": {
    "endpoints": [
      {
        "method": "string - HTTP method",
        "path": "string - endpoint path",
        "source": "string - file:line where discovered",
        "has_path_params": "boolean",
        "path_params": ["string - parameter names"],
        "expected_body": "object|null - example body if found"
      }
    ],
    "auth_detected": "boolean - whether auth seems required",
    "auth_type": "string|null - Bearer, API Key, Basic, etc.",
    "auth_source": "string|null - where auth config was found"
  },
  "results": [
    {
      "endpoint": "string - METHOD /path",
      "discovered_from": "string - source file:line",
      "request": {
        "method": "string",
        "url": "string - full URL",
        "headers": "object - request headers",
        "body": "object|string|null - request body"
      },
      "response": {
        "status": "number - HTTP status code",
        "headers": "object - response headers",
        "body": "object|string - response body",
        "duration_ms": "number - request duration"
      },
      "error": "string|null - error message if request failed",
      "passed": "boolean - true if status < 400 and no error"
    }
  ],
  "server_logs": "string - captured stdout/stderr (truncated if large)",
  "errors": [
    {
      "phase": "string - startup|discovery|testing|shutdown",
      "message": "string - error description",
      "details": "string|null - additional context"
    }
  ]
}
```

## Example: Successful Report

```json
{
  "summary": {
    "plan_file": "docs/planning/story-3-1.md",
    "server_command": "npm run dev",
    "endpoints_discovered": 3,
    "endpoints_tested": 3,
    "passed": 3,
    "failed": 0,
    "health_endpoint": "/api/health",
    "startup_time_ms": 2340,
    "total_test_time_ms": 156
  },
  "discovery": {
    "endpoints": [
      {
        "method": "GET",
        "path": "/api/users",
        "source": "story-3-1.md:47",
        "has_path_params": false,
        "path_params": [],
        "expected_body": null
      },
      {
        "method": "POST",
        "path": "/api/users",
        "source": "story-3-1.md:52",
        "has_path_params": false,
        "path_params": [],
        "expected_body": {"name": "string", "email": "string"}
      },
      {
        "method": "GET",
        "path": "/api/users/{id}",
        "source": "story-3-1.md:58",
        "has_path_params": true,
        "path_params": ["id"],
        "expected_body": null
      }
    ],
    "auth_detected": true,
    "auth_type": "Bearer",
    "auth_source": ".env.test"
  },
  "results": [
    {
      "endpoint": "GET /api/users",
      "discovered_from": "story-3-1.md:47",
      "request": {
        "method": "GET",
        "url": "http://localhost:3000/api/users",
        "headers": {
          "Authorization": "Bearer test-token-xxx",
          "Accept": "application/json"
        },
        "body": null
      },
      "response": {
        "status": 200,
        "headers": {
          "content-type": "application/json",
          "x-request-id": "abc123"
        },
        "body": {
          "users": [
            {"id": 1, "name": "Alice"},
            {"id": 2, "name": "Bob"}
          ]
        },
        "duration_ms": 45
      },
      "error": null,
      "passed": true
    },
    {
      "endpoint": "POST /api/users",
      "discovered_from": "story-3-1.md:52",
      "request": {
        "method": "POST",
        "url": "http://localhost:3000/api/users",
        "headers": {
          "Authorization": "Bearer test-token-xxx",
          "Content-Type": "application/json"
        },
        "body": {"name": "Test User", "email": "test@example.com"}
      },
      "response": {
        "status": 201,
        "headers": {"content-type": "application/json"},
        "body": {"id": 3, "name": "Test User", "email": "test@example.com"},
        "duration_ms": 67
      },
      "error": null,
      "passed": true
    },
    {
      "endpoint": "GET /api/users/{id}",
      "discovered_from": "story-3-1.md:58",
      "request": {
        "method": "GET",
        "url": "http://localhost:3000/api/users/1",
        "headers": {
          "Authorization": "Bearer test-token-xxx"
        },
        "body": null
      },
      "response": {
        "status": 200,
        "headers": {"content-type": "application/json"},
        "body": {"id": 1, "name": "Alice", "email": "alice@example.com"},
        "duration_ms": 44
      },
      "error": null,
      "passed": true
    }
  ],
  "server_logs": "[INFO] Server started on port 3000\n[INFO] Connected to database\n[INFO] GET /api/health 200 5ms\n[INFO] GET /api/users 200 45ms\n...",
  "errors": []
}
```

## Example: Partial Failure Report

```json
{
  "summary": {
    "plan_file": "docs/api-spec.md",
    "server_command": "python manage.py runserver",
    "endpoints_discovered": 2,
    "endpoints_tested": 2,
    "passed": 1,
    "failed": 1,
    "health_endpoint": "/health",
    "startup_time_ms": 3200,
    "total_test_time_ms": 89
  },
  "discovery": {
    "endpoints": [
      {"method": "GET", "path": "/api/products", "source": "api-spec.md:15", "has_path_params": false, "path_params": [], "expected_body": null},
      {"method": "GET", "path": "/api/products/{id}", "source": "api-spec.md:22", "has_path_params": true, "path_params": ["id"], "expected_body": null}
    ],
    "auth_detected": false,
    "auth_type": null,
    "auth_source": null
  },
  "results": [
    {
      "endpoint": "GET /api/products",
      "discovered_from": "api-spec.md:15",
      "request": {"method": "GET", "url": "http://localhost:8000/api/products", "headers": {}, "body": null},
      "response": {"status": 200, "headers": {}, "body": [], "duration_ms": 34},
      "error": null,
      "passed": true
    },
    {
      "endpoint": "GET /api/products/{id}",
      "discovered_from": "api-spec.md:22",
      "request": {"method": "GET", "url": "http://localhost:8000/api/products/1", "headers": {}, "body": null},
      "response": {"status": 404, "headers": {}, "body": {"error": "Product not found"}, "duration_ms": 55},
      "error": null,
      "passed": false
    }
  ],
  "server_logs": "Starting development server at http://127.0.0.1:8000/\n...",
  "errors": []
}
```

## Example: Startup Failure Report

```json
{
  "summary": {
    "plan_file": "docs/story.md",
    "server_command": "npm run dev",
    "endpoints_discovered": 5,
    "endpoints_tested": 0,
    "passed": 0,
    "failed": 0,
    "health_endpoint": null,
    "startup_time_ms": 30000,
    "total_test_time_ms": 0
  },
  "discovery": {
    "endpoints": [
      {"method": "GET", "path": "/api/users", "source": "story.md:10", "has_path_params": false, "path_params": [], "expected_body": null}
    ],
    "auth_detected": false,
    "auth_type": null,
    "auth_source": null
  },
  "results": [],
  "server_logs": "npm ERR! Missing script: dev\nnpm ERR! To see a list of scripts, run: npm run",
  "errors": [
    {
      "phase": "startup",
      "message": "Server failed to start within 30s timeout",
      "details": "Health endpoint /health never responded. Check server_logs for errors."
    }
  ]
}
```

## Status Code Interpretation

| Range | Meaning | passed |
|-------|---------|--------|
| 2xx | Success | true |
| 3xx | Redirect | true |
| 4xx | Client error | false |
| 5xx | Server error | false |
| N/A | Connection/timeout error | false |
