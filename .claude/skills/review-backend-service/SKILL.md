---
name: review-backend-service
description: Start a backend server, discover API endpoints from a plan/story file, test each endpoint, capture responses and logs, then return a structured report. This skill should be used when testing backend API implementations against a plan, story, or specification file. Takes a required plan file path and an optional server start command.
---

# Review Backend Service

Start a server, discover API endpoints from a plan file, test them, capture responses and logs, stop the server, and return a structured report.

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `plan_path` | Yes | Path to plan/story/spec file containing endpoint definitions |
| `server_command` | No | Command to start the server (auto-detected if not provided) |

## Workflow

### 1. Parse Arguments

Extract from the invocation:
- `plan_path` - Required path to the plan/story file
- `server_command` - Optional server start command

### 2. Auto-Detect Server Command (if not provided)

If no `server_command` is provided, detect from project context:

1. Check `package.json` for scripts: `dev`, `start`, `serve`
2. Check for `Makefile` with `run`, `serve`, `dev` targets
3. Check for `docker-compose.yml`
4. Check for common patterns: `go run`, `python manage.py runserver`, `cargo run`
5. If detection fails, ask the user

### 3. Discover Endpoints from Plan File

Read the plan file and extract endpoints using patterns from [endpoint-patterns.md](references/endpoint-patterns.md).

**Sources to scan:**
- The provided plan file
- Any referenced architecture or API docs

**Pattern matching:**
- HTTP method + path patterns: `GET /api/...`, `POST /users`
- Acceptance criteria: "When I call GET /users..."
- Implementation notes and dev documentation

**Fallback:** If no endpoints discovered, note this in the report.

### 4. Detect Health Endpoint

Try common health check patterns in order:
1. `/health`
2. `/api/health`
3. `/healthz`
4. `/api/healthz`
5. `/` (root)

Use the first one that responds successfully.

### 5. Start Server

1. Run the server command in background
2. Capture stdout/stderr to `server_logs`
3. Poll health endpoint until ready (timeout: 30s)
4. If startup fails, include error in report and abort

### 6. Test Endpoints

For each discovered endpoint, use [test_endpoint.py](scripts/test_endpoint.py):

```bash
python scripts/test_endpoint.py --method GET --url "http://localhost:3000/api/users" [--auth-header "Bearer token"]
```

**Authentication handling:**
- Check for auth configuration in project (env files, config)
- Look for test tokens or API keys
- If auth required but not found, note in report and attempt unauthenticated

Capture for each endpoint:
- Request details (method, URL, headers, body)
- Response (status, headers, body, duration)
- Any errors

### 7. Stop Server

1. Send SIGTERM to server process
2. Wait up to 5s for graceful shutdown
3. Send SIGKILL if still running

### 8. Generate Report

Return a structured report to the main agent using the format from [output-formats.md](references/output-formats.md).

## Report Format

Return the report as a structured response (not saved to files):

```json
{
  "summary": {
    "plan_file": "path/to/plan.md",
    "server_command": "npm run dev",
    "endpoints_discovered": 5,
    "endpoints_tested": 5,
    "passed": 4,
    "failed": 1,
    "health_endpoint": "/api/health"
  },
  "discovery": {
    "endpoints": [
      {"method": "GET", "path": "/api/users", "source": "plan.md:47"}
    ],
    "auth_detected": true,
    "auth_type": "Bearer token"
  },
  "results": [
    {
      "endpoint": "GET /api/users",
      "discovered_from": "plan.md:47",
      "request": {
        "method": "GET",
        "url": "http://localhost:3000/api/users",
        "headers": {"Authorization": "Bearer ..."}
      },
      "response": {
        "status": 200,
        "headers": {"content-type": "application/json"},
        "body": {},
        "duration_ms": 45
      },
      "error": null,
      "passed": true
    }
  ],
  "server_logs": "... truncated server output ...",
  "errors": []
}
```

## Error Handling

| Scenario | Action |
|----------|--------|
| Server fails to start | Report error, abort testing |
| Health check timeout | Report error, abort testing |
| Endpoint returns error | Record in results, continue testing |
| Auth required but missing | Note in report, attempt without auth |
| No endpoints discovered | Report empty discovery, skip testing |

## Resources

- [scripts/test_endpoint.py](scripts/test_endpoint.py) - HTTP request utility with response capture
- [references/endpoint-patterns.md](references/endpoint-patterns.md) - Regex patterns for endpoint discovery
- [references/output-formats.md](references/output-formats.md) - JSON schemas for report structure
