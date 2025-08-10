# 🚀 Project Rulebook API Testing Guide

Complete guide for testing the Project Rulebook Vapor backend API endpoints.

## 📁 Quick Import

**Postman/RapidAPI Collection**: `Project-Rulebook-API-Testing.postman_collection.json`

1. **Import into Postman**: File → Import → Select the JSON file
2. **Import into RapidAPI**: Projects → Import → Upload Collection File

## 🔐 Authentication Setup

### Admin User Credentials (Pre-seeded)
```
Email: root@localhost.com
Password: ChangeMe1
Role: Admin (can access cache management endpoints)
```

### Authentication Flow
1. **First**: Run `Authentication → Admin Login` request
2. **Result**: JWT tokens automatically stored in environment variables
3. **Usage**: Admin endpoints automatically use stored `access_token`

## 🌐 Environment Configuration

### Required Environment Variables
| Variable | Default Value | Description |
|----------|---------------|-------------|
| `base_url` | `http://localhost:8080` | API server base URL |
| `admin_email` | `root@localhost.com` | Admin user email |
| `admin_password` | `ChangeMe1` | Admin user password |
| `access_token` | (auto-set) | JWT access token from login |
| `refresh_token` | (auto-set) | JWT refresh token from login |

### Environment Setup Options

#### Option 1: Local Development
```
base_url = http://localhost:8080
```

#### Option 2: Docker Development
```
base_url = http://localhost:8080
```

#### Option 3: Custom Host/Port
```
base_url = http://your-host:your-port
```

## 🎯 Available Endpoints

### 1. Authentication Endpoints (`/api/auth`)

#### Admin Login
```http
POST /api/auth/sign-in
Content-Type: application/json

{
  "email": "root@localhost.com",
  "password": "ChangeMe1"
}
```

**Response Example**:
```json
{
  "token": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  },
  "user": {
    "id": "uuid",
    "email": "root@localhost.com",
    "firstName": "John",
    "lastName": "Doe",
    "isAdmin": true
  }
}
```

#### User Signup
```http
POST /api/auth/sign-up
Content-Type: application/json

{
  "email": "test@example.com",
  "password": "TestPassword123",
  "firstName": "Test",
  "lastName": "User"
}
```

### 2. Rules Generation Endpoints (`/api/rules-generation`)

#### Game Box Image Analysis
```http
POST /api/rules-generation/game-box-analysis
Content-Type: application/octet-stream

[Binary image data]
```

**⚠️ IMPORTANT**: This endpoint now accepts raw binary image data directly - no JSON wrapper or base64 encoding needed.

**How to send image data**:
- **Postman**: Body → binary → Select File
- **cURL**: `curl -X POST -H "Content-Type: application/octet-stream" --data-binary @your-image.png http://localhost:8080/api/rules-generation/game-box-analysis`
- **Code**: Send raw image bytes in request body

**Rate Limits**:
- Development: 50 requests/hour
- Production: 3 requests/hour

**Expected Response**:
```json
{
  "guessedTitle": "Monopoly",
  "confidence": 95,
  "alternativeTitles": ["Monopoly Classic", "Monopoly Standard"],
  "keywordsDetected": ["Parker Brothers", "Real Estate Game", "Board Game"],
  "notes": "Clear title visibility on box, high confidence match based on distinctive logo and branding"
}
```

#### Rules Summary Generation
```http
POST /api/rules-generation/rules-summary
Content-Type: application/json

{
  "gameTitle": "Monopoly"
}
```

**Rate Limits**:
- Development: 100 requests/hour
- Production: 5 requests/hour

**Expected Response**:
```json
{
  "title": "Monopoly",
  "playerCount": "2-8 players",
  "playTime": "60-180 minutes",
  "summary": "A real estate trading game where players buy, sell, and develop properties to bankrupt their opponents.",
  "initialSetup": [
    "Place the board in the center of the table",
    "Each player chooses a token and places it on GO",
    "Shuffle the Chance and Community Chest cards",
    "Each player receives $1,500 starting money"
  ],
  "firstRoundGuide": [
    "Roll both dice and move clockwise around the board",
    "Buy any unowned property you land on, or it goes to auction",
    "Pay rent if you land on another player's property",
    "Draw a card if you land on Chance or Community Chest"
  ],
  "winCondition": "Be the last player remaining when all others have gone bankrupt",
  "deepDive": [
    "Build houses and hotels to increase rent prices",
    "Trade properties to create monopolies",
    "Manage cash flow carefully to avoid bankruptcy"
  ],
  "resources": {
    "videoLinks": [
      "https://www.youtube.com/watch?v=4nxm6b6Y7M0"
    ],
    "webLinks": [
      "https://boardgamegeek.com/boardgame/1406/monopoly",
      "https://www.hasbro.com/en-us/product/monopoly-classic-game"
    ]
  },
  "confidence": 90,
  "notes": "Classic game with well-established rules and widespread documentation"
}
```

### 3. Cache Administration Endpoints (`/api/admin/cache`)

**⚠️ Requires Admin Authentication** - Include `Authorization: Bearer {access_token}` header

#### Cache Statistics
```http
GET /api/admin/cache/stats
Authorization: Bearer {access_token}
```

**Response Example**:
```json
{
  "hits": 150,
  "misses": 25,
  "entryCount": 45,
  "maxEntries": 1000,
  "hitRatio": 85.7,
  "utilization": 4.5
}
```

#### Cache Health Check
```http
GET /api/admin/cache/health
Authorization: Bearer {access_token}
```

#### List Cache Entries
```http
GET /api/admin/cache/entries
Authorization: Bearer {access_token}
```

**Response Example**:
```json
{
  "rules_generation": ["rules_abc123", "rules_def456"],
  "image_analysis": ["image_ghi789", "image_jkl012"]
}
```

#### Manual Cache Cleanup
```http
POST /api/admin/cache/cleanup
Authorization: Bearer {access_token}
```

#### Clear Entire Cache
```http
DELETE /api/admin/cache
Authorization: Bearer {access_token}
```

**⚠️ DESTRUCTIVE ACTION**: Removes all cached data

## 🔍 Testing Scenarios

### Scenario 1: Complete Flow Testing
1. **Login** → Get admin tokens
2. **Upload Game Image** → Get game identification
3. **Generate Rules** → Use identified game title
4. **Check Cache** → Verify caching is working
5. **Clear Cache** → Test cache management

### Scenario 2: Rate Limit Testing
1. **Rapid Requests** → Test rate limiting kicks in
2. **Check Headers** → Verify rate limit headers
3. **Wait and Retry** → Confirm limits reset

### Scenario 3: Error Handling
1. **Invalid Auth** → Test unauthorized responses
2. **Bad Payloads** → Test validation errors
3. **Large Images** → Test file size limits

## 🚦 Rate Limiting Information

All endpoints include rate limit headers:
- `X-RateLimit-Limit`: Maximum requests allowed
- `X-RateLimit-Remaining`: Requests remaining in window
- `X-RateLimit-Type`: Type of rate limit applied
- `X-RateLimit-Window`: Time window in seconds

### Rate Limit Types
- `image_analysis`: Image upload endpoints
- `rules_generation`: Rules generation endpoints
- `admin`: Admin-only endpoints
- `api`: General API endpoints
- `general`: Web requests

## 🐛 Troubleshooting

### Common Issues

#### "Request is missing JWT bearer header"
```
[ ERROR ] Request is missing JWT bearer header
[ WARNING ] Abort.401: Unauthorized
```
**Causes & Solutions**:
1. **Not logged in**: Run "Authentication → Admin Login" first
2. **Wrong token extraction**: Updated collection now extracts `response.token.accessToken`
3. **Token expired**: JWT tokens expire after 15 minutes - re-login
4. **Missing Authorization header**: Ensure format is `Authorization: Bearer {token}`

#### "Invalid JSON in image analysis request" 
```
[ WARNING ] Invalid JSON in image analysis request
[ WARNING ] Abort.400: Invalid request format
```
**Cause**: The endpoint expects JSON with base64 image data, not form-data uploads
**Solution**: 
1. Convert image to base64: `base64 -i your-image.png`
2. Send as JSON: `{"image": "base64-data-here"}`
3. Use `Content-Type: application/json`

#### Authentication Problems
```json
{
  "error": "unauthorized", 
  "reason": "Invalid or expired token"
}
```
**Solution**: Re-run the "Admin Login" request to get fresh tokens

#### Rate Limit Exceeded
```json
{
  "error": "rate_limit_exceeded",
  "message": "AI image_analysis rate limit exceeded",
  "retryAfter": 3600
}
```
**Solution**: Wait for the specified retry time or use development configuration

#### File Upload Issues
```json
{
  "error": "validation_failed",
  "reason": "Invalid image format - must be valid base64 encoded image"
}
```
**Solution**: Ensure image is PNG, JPG, or JPEG format and under size limits

### Server Connection Issues
1. **Check Server Status**: Ensure `swift run App serve` is running
2. **Verify Port**: Default is 8080, check if different
3. **Check Environment**: Ensure environment variables are loaded

## 🔧 Development Commands

### Start Server
```bash
# Standard development
swift run App serve --hostname 0.0.0.0 --port 8080

# Docker development  
docker-compose up --build
```

### Build and Test
```bash
# Build project
swift build

# Run tests
swift test
```

## 📊 Success Indicators

### ✅ Successful Test Results
- **Authentication**: 200 status with JWT tokens
- **Image Analysis**: 200 status with game detection
- **Rules Generation**: 200 status with comprehensive rules
- **Cache Operations**: 200 status with appropriate responses
- **Rate Limits**: Headers present and accurate

### ❌ Common Error Codes
- `400`: Bad Request - Invalid payload
- `401`: Unauthorized - Missing/invalid authentication
- `403`: Forbidden - Admin access required
- `413`: Payload Too Large - File too big
- `429`: Too Many Requests - Rate limited

## 🎯 Testing Tips

1. **Start with Authentication**: Always run admin login first
2. **Use Small Images**: For faster testing, use small game box images
3. **Check Rate Limits**: Monitor the `X-RateLimit-Remaining` header
4. **Test Caching**: Make the same request twice to see cache hits
5. **Clear Cache**: Use admin endpoints to reset cache between tests
6. **Monitor Logs**: Watch server logs for detailed error information

## 📱 Integration Examples

### Frontend Integration
```javascript
// Login and store token
const loginResponse = await fetch('/api/auth/sign-in', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    email: 'root@localhost.com', 
    password: 'ChangeMe1' 
  })
});
const { accessToken } = await loginResponse.json();

// Use token for protected endpoints
const cacheStats = await fetch('/api/admin/cache/stats', {
  headers: { 'Authorization': `Bearer ${accessToken}` }
});
```

### Mobile App Integration
```swift
// Swift/iOS example
struct APIClient {
    private let baseURL = "http://localhost:8080"
    private var accessToken: String?
    
    func login() async throws {
        // Login implementation
    }
    
    func analyzeGameBox(imageData: Data) async throws -> GameboxRecognition {
        // Image analysis implementation with auth headers
    }
}
```

---

**🎉 Happy Testing!** 

For issues or questions, check the server logs or create an issue in the project repository.