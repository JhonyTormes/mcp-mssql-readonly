-- ============================================================
-- Server-level DDL trigger that automatically provisions the
-- mcp_readonly user in every new database created on the server.
--
-- Run in SQL Server Management Studio (SSMS) with sysadmin
-- privileges. This only needs to be run once per server.
-- ============================================================

CREATE OR ALTER TRIGGER [trg_create_mcp_readonly_user]
ON ALL SERVER
FOR CREATE_DATABASE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dbName sysname;
    DECLARE @sql nvarchar(max);

    -- Extract the database name from EVENTDATA()
    -- CREATE_DATABASE provides: <EventType>CREATE_DATABASE</EventType>
    --                             <DatabaseName>...</DatabaseName>
    SELECT @dbName = EVENTDATA().value('(/EVENT_INSTANCE/DatabaseName)[1]', 'sysname');

    IF @dbName IS NULL
        RETURN;

    -- Skip system databases just in case (they shouldn't fire CREATE_DATABASE,
    -- but being defensive is cheap)
    IF @dbName IN ('master', 'tempdb', 'model', 'msdb')
        RETURN;

    -- Check if the mcp_readonly login exists before proceeding
    IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'mcp_readonly' AND type = 'S')
    BEGIN
        PRINT 'Trigger [trg_create_mcp_readonly_user]: Login [mcp_readonly] does not exist. Skipping.';
        RETURN;
    END

    BEGIN TRY
        SET @sql = N'
            USE [' + @dbName + N'];
            IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N''mcp_readonly'')
            BEGIN
                CREATE USER [mcp_readonly] FOR LOGIN [mcp_readonly];
                ALTER ROLE [db_datareader] ADD MEMBER [mcp_readonly];
                GRANT VIEW DEFINITION TO [mcp_readonly];
                DENY INSERT, UPDATE, DELETE, ALTER TO [mcp_readonly];
                PRINT ''User [mcp_readonly] auto-provisioned in new database [' + @dbName + N'].'';
            END';

        EXEC sp_executesql @sql;
    END TRY
    BEGIN CATCH
        -- Log the error but do NOT roll back the database creation
        DECLARE @msg nvarchar(4000) = 'Trigger [trg_create_mcp_readonly_user] failed for database ['
            + @dbName + N']: ' + ERROR_MESSAGE();
        PRINT @msg;
    END CATCH
END;
GO

-- ============================================================
-- To verify the trigger exists:
--   SELECT * FROM sys.server_triggers WHERE name = 'trg_create_mcp_readonly_user';
-- ============================================================
-- To remove:
--   DROP TRIGGER [trg_create_mcp_readonly_user] ON ALL SERVER;
-- ============================================================
