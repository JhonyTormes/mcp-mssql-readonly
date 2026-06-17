-- ============================================================
-- Creates a read-only SQL Server login and user for the MCP server
-- Run in SQL Server Management Studio (SSMS) with sysadmin privileges
-- ============================================================

-- 1. Create server-level login
CREATE LOGIN mcp_readonly WITH PASSWORD = 'YourStrongPasswordHere!';

-- 2. Create database-level user
--    Repeat this section for each database the MCP server needs to access
USE [YourDatabaseName];
CREATE USER mcp_readonly FOR LOGIN mcp_readonly;

-- 3. Grant read access to all tables/views (existing and future)
ALTER ROLE db_datareader ADD MEMBER mcp_readonly;

-- 4. Allow viewing metadata (schemas, columns, foreign keys, indexes, etc.)
GRANT VIEW DEFINITION TO mcp_readonly;

-- 5. Explicitly deny write operations as an extra safety layer
DENY INSERT, UPDATE, DELETE, ALTER, CONTROL TO mcp_readonly;

-- ============================================================
-- Connection string example for MCP:
-- Server=YourServer;Database=YourDatabase;User Id=mcp_readonly;Password=YourStrongPasswordHere!;TrustServerCertificate=True;
-- ============================================================

-- To revoke (if needed):
-- USE [YourDatabaseName];
-- DROP USER mcp_readonly;
-- DROP LOGIN mcp_readonly;
