-- ============================================================
-- Creates a read-only SQL Server login and user across ALL
-- non-system databases in a single execution.
--
-- Run in SQL Server Management Studio (SSMS) with sysadmin
-- or server-level security-admin privileges.
-- ============================================================

-- 1. Create server-level login (if not already exists)
--    Note: DEFAULT_DATABASE is set to the first user database later in this script
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'mcp_readonly')
BEGIN
    CREATE LOGIN mcp_readonly WITH PASSWORD = 'YourStrongPasswordHere!';
    PRINT 'Login [mcp_readonly] created.';
END
ELSE
    PRINT 'Login [mcp_readonly] already exists.';

-- 2. Create a database user in every online user database
DECLARE @dbName sysname;
DECLARE @sql nvarchar(max);

DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name
    FROM sys.databases
    WHERE state = 0                    -- online
      AND database_id > 4              -- exclude master, tempdb, model, msdb
      AND is_read_only = 0             -- skip read-only databases
    ORDER BY name;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
        USE [' + @dbName + N'];
        IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''mcp_readonly'')
        BEGIN
            CREATE USER [mcp_readonly] FOR LOGIN [mcp_readonly];
            ALTER ROLE [db_datareader] ADD MEMBER [mcp_readonly];
            GRANT VIEW DEFINITION TO [mcp_readonly];
            DENY INSERT, UPDATE, DELETE, ALTER TO [mcp_readonly];
            PRINT ''  Created user [mcp_readonly] in database [' + @dbName + N']'';
        END
        ELSE
            PRINT ''  User [mcp_readonly] already exists in database [' + @dbName + N']'';';

    EXEC sp_executesql @sql;
    FETCH NEXT FROM db_cursor INTO @dbName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- 3. Set default database to the first user database so SSMS
--    Object Explorer and IntelliSense work out of the box
DECLARE @firstDb sysname;
SELECT TOP 1 @firstDb = name
FROM sys.databases
WHERE state = 0
  AND database_id > 4
  AND is_read_only = 0
ORDER BY name;

IF @firstDb IS NOT NULL
BEGIN
    DECLARE @alterSql nvarchar(max) = N'ALTER LOGIN [mcp_readonly] WITH DEFAULT_DATABASE = [' + @firstDb + N'];';
    EXEC sp_executesql @alterSql;
    PRINT 'Default database set to [' + @firstDb + '].';
END

PRINT 'Done.';
GO

-- ============================================================
-- Connection string example for MCP:
-- Server=YourServer;Database=YourDatabase;User Id=mcp_readonly;Password=YourStrongPasswordHere!;TrustServerCertificate=True;
-- ============================================================

-- To revoke across all databases, run:
--   DECLARE db_cursor CURSOR FOR SELECT name FROM sys.databases WHERE state = 0 AND database_id > 4;
--   OPEN db_cursor; FETCH NEXT FROM db_cursor INTO @dbName;
--   WHILE @@FETCH_STATUS = 0
--   BEGIN
--       SET @sql = 'USE [' + @dbName + ']; DROP USER IF EXISTS [mcp_readonly];';
--       EXEC sp_executesql @sql;
--       FETCH NEXT FROM db_cursor INTO @dbName;
--   END
--   CLOSE db_cursor; DEALLOCATE db_cursor;
--   DROP LOGIN IF EXISTS mcp_readonly;
-- ============================================================
