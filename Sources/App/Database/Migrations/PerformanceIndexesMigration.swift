import Fluent
import FluentSQL
import Vapor

/// Migration to add performance indexes for frequently queried fields
struct PerformanceIndexesMigration: AsyncMigration {
    func prepare(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            // For non-SQL databases, skip index creation
            return
        }
        
        // Indexes for refresh_tokens table
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens (user_id)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires_at ON refresh_tokens (expires_at)").run()
        
        // Indexes for email_tokens table  
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_email_tokens_user_id ON email_tokens (user_id)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_email_tokens_expires_at ON email_tokens (expires_at)").run()
        
        // Indexes for password_tokens table
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_password_tokens_user_id ON password_tokens (user_id)").run()
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_password_tokens_expires_at ON password_tokens (expires_at)").run()
        
        // Index for users table (Apple Sign In lookups) - handle potential null values
        try await sql.raw("CREATE INDEX IF NOT EXISTS idx_users_apple_identifier ON users (apple_user_identifier) WHERE apple_user_identifier IS NOT NULL").run()
    }
    
    func revert(on database: Database) async throws {
        guard let sql = database as? SQLDatabase else {
            return
        }
        
        // Drop indexes in reverse order
        try await sql.raw("DROP INDEX IF EXISTS idx_users_apple_identifier").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_password_tokens_expires_at").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_password_tokens_user_id").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_email_tokens_expires_at").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_email_tokens_user_id").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_refresh_tokens_expires_at").run()
        try await sql.raw("DROP INDEX IF EXISTS idx_refresh_tokens_user_id").run()
    }
}