-- ============================================================
-- Creates a read-only SQL Server login and user for the MCP server
-- Run in SQL Server Management Studio (SSMS) with sysadmin privileges
-- ============================================================

-- 1. Create server-level login (idempotent)
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'mcp_readonly')
BEGIN
    CREATE LOGIN mcp_readonly
        WITH PASSWORD = 'YourStrongPasswordHere!',
             DEFAULT_DATABASE = [YourDatabaseName];
    PRINT 'Login [mcp_readonly] created.';
END
ELSE
    PRINT 'Login [mcp_readonly] already exists.';

-- 2. Create database-level user (idempotent)
--    Repeat this section for each database the MCP server needs to access
USE [YourDatabaseName];
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'mcp_readonly')
BEGIN
    CREATE USER mcp_readonly FOR LOGIN mcp_readonly;
    PRINT 'User [mcp_readonly] created in [YourDatabaseName].';
END
ELSE
    PRINT 'User [mcp_readonly] already exists in [YourDatabaseName].';

-- 3. Grant read access to all tables/views (existing and future)
ALTER ROLE db_datareader ADD MEMBER mcp_readonly;

-- 4. Allow viewing metadata (schemas, columns, foreign keys, indexes, etc.)
GRANT VIEW DEFINITION TO mcp_readonly;

-- 5. Explicitly deny write operations as an extra safety layer
--    Note: CONTROL is intentionally NOT denied, as it blocks SSMS metadata
--    visibility even with VIEW DEFINITION granted.
DENY INSERT, UPDATE, DELETE, ALTER TO mcp_readonly;

-- ============================================================
-- Connection string example for MCP:
-- Server=YourServer;Database=YourDatabase;User Id=mcp_readonly;Password=YourStrongPasswordHere!;TrustServerCertificate=True;
-- ============================================================

-- To revoke (if needed):
-- USE [YourDatabaseName];
-- DROP USER IF EXISTS mcp_readonly;
-- DROP LOGIN IF EXISTS mcp_readonly;
