# Xcode Development Setup

This guide helps you run the Vapor application directly from Xcode without runtime errors.

## Environment Variables Setup

Xcode doesn't automatically load `.env` files, so you need to configure environment variables manually:

### Step 1: Open Scheme Editor
1. In Xcode, go to **Product** → **Scheme** → **Edit Scheme...**
2. Select **Run** in the left sidebar
3. Go to **Arguments** tab
4. Select **Environment Variables** section

### Step 2: Add Required Variables
Copy these environment variables from `.xcode.env` file:

```
JWT_KEY = development_jwt_secret_key_minimum_32_characters_required_for_security
DATABASE_HOST = localhost
DATABASE_NAME = project_rulebook_dev
DATABASE_USERNAME = vapor
DATABASE_PASSWORD = password
DATABASE_PORT = 5432
BASE_URL = http://localhost:8080
APPLICATION_IDENTIFIER = com.dev.app
BREVO_API_KEY = dev_brevo_key
BREVO_URL = https://api.brevo.com
OPENAI_KEY = dev_openai_key
AWS_ACCESS_KEY = dev_access_key
AWS_SECRET_ACCESS_KEY = dev_secret_key
AWS_REGION = us-west-2
AWS_S3_BUCKET_NAME = dev-bucket
APNS_KEY = dev_apns_key
APNS_PRIVATE_KEY = dev_private_key
APNS_TEAM_ID = DEV_TEAM_ID
```

### Step 3: Set Working Directory (Optional)
1. In **Edit Scheme** → **Run** → **Options**
2. Check **Use custom working directory**
3. Set it to your project root directory (where Package.swift is located)

## Database Configuration

The application is configured to use SQLite in-memory for development, so no additional database setup is required for Xcode runs.

## Common Issues & Solutions

### Issue: "Configuration validation failed for JWT"
**Solution:** Ensure the `JWT_KEY` environment variable is set in Xcode scheme (Step 2 above)

### Issue: "Application.shutdown() was not called"
**Solution:** This has been fixed in the entrypoint. The app now properly calls shutdown on exit.

### Issue: "Cannot connect to database"
**Solution:** Development environment uses SQLite in-memory, so no external database connection is needed.

## Testing the Setup

1. Set up environment variables as described above
2. Run the project from Xcode (⌘+R)
3. You should see logs indicating successful startup:
   ```
   [ INFO ] Configuration loaded for environment: development
   [ INFO ] Database host: localhost
   [ INFO ] Services configured: Brevo, OpenAI
   [ INFO ] Server starting on http://localhost:8080
   ```

## Alternative: Command Line Development

If you prefer command line development:
```bash
# Copy environment template
cp .env.example .env

# Run the application
swift run App serve
```

This approach automatically loads the `.env` file and doesn't require Xcode scheme configuration.