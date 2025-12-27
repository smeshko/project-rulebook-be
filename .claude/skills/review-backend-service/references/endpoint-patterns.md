# Endpoint Discovery Patterns

Regex patterns and examples for discovering API endpoints in plan/story files.

## Primary Patterns

### HTTP Method + Path

Match explicit HTTP method and path combinations:

```regex
(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(/[a-zA-Z0-9/_\-\{\}:]+)
```

**Examples matched:**
- `GET /api/users`
- `POST /api/users/{id}`
- `DELETE /api/users/:id`
- `PUT /api/v2/products`

### Endpoint in Backticks

Match endpoints wrapped in code formatting:

```regex
`(GET|POST|PUT|PATCH|DELETE)\s+(/[a-zA-Z0-9/_\-\{\}:]+)`
```

**Examples matched:**
- `` `GET /api/users` ``
- `` `POST /api/orders` ``

### URL Path Patterns

Match standalone API paths (when method is implied or separate):

```regex
(/api/[a-zA-Z0-9/_\-\{\}:]+)
```

**Examples matched:**
- `/api/users`
- `/api/v1/products/{id}`
- `/api/auth/login`

## Contextual Patterns

### Acceptance Criteria

Common patterns in user stories:

```regex
(?:When|Given|Then).*?(?:call|request|hit|fetch|send)\s+(?:a\s+)?(GET|POST|PUT|PATCH|DELETE)?\s*(?:to\s+)?[`"]?(/[a-zA-Z0-9/_\-\{\}:]+)
```

**Examples matched:**
- `When I call GET /api/users`
- `Given a request to /api/products`
- `Then send POST to /api/orders`

### Table Format

Endpoints defined in markdown tables:

```regex
\|\s*(GET|POST|PUT|PATCH|DELETE)\s*\|\s*(/[a-zA-Z0-9/_\-\{\}:]+)\s*\|
```

**Examples matched:**
- `| GET | /api/users |`
- `| POST | /api/orders |`

### Route Definitions

Common in implementation notes:

```regex
(?:route|endpoint|path)[:=]\s*[`"']?(GET|POST|PUT|PATCH|DELETE)?\s*(/[a-zA-Z0-9/_\-\{\}:]+)
```

**Examples matched:**
- `route: GET /api/users`
- `endpoint = "/api/products"`
- `path: '/api/auth/login'`

## Request Body Patterns

### JSON Body Examples

Detect if an endpoint expects a request body:

```regex
(?:body|payload|request):\s*```json\s*([\s\S]*?)```
```

### Content-Type Hints

```regex
Content-Type:\s*(application/json|multipart/form-data|application/x-www-form-urlencoded)
```

## Auth Patterns

Detect authentication requirements:

```regex
(?:requires?|needs?|with)\s+(?:auth|authentication|authorization|token|bearer|api[- ]?key)
```

**Indicators:**
- `requires authentication`
- `needs bearer token`
- `with API key`

## Path Parameter Extraction

Extract path parameters for test data:

```regex
[{:]([a-zA-Z][a-zA-Z0-9_]*)
```

**Examples:**
- `/api/users/{id}` → `id`
- `/api/users/:userId` → `userId`
- `/api/products/{productId}/reviews/{reviewId}` → `productId`, `reviewId`

## Discovery Priority

1. **Explicit method + path** - Most reliable
2. **Table format** - Structured, likely complete
3. **Acceptance criteria** - User-facing, important
4. **Backtick format** - Code references
5. **Standalone paths** - May need method inference (default to GET)

## Inference Rules

When method is not specified:
- Paths with `/create`, `/add`, `/new` → POST
- Paths with `/update`, `/edit` → PUT or PATCH
- Paths with `/delete`, `/remove` → DELETE
- All others → GET (safe default for discovery)
