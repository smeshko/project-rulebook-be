# Xcode Development Setup

This guide helps you run the Vapor application directly from Xcode without runtime errors.

## Environment Variables Setup

The application now automatically loads environment variables from the `.env` file, so no manual configuration is needed in Xcode.

### Automatic Loading
The application will automatically load your `.env` file when it starts, whether you run from:
- Xcode
- Command line (`swift run`)
- VS Code
- Docker

### Step 1: Create Your .env File
Copy the example file and add your actual API keys:

```bash
cp .env.example .env
# Edit .env and add your actual API keys
```

### Step 2: Set Working Directory (Optional)
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