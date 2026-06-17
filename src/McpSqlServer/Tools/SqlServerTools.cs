using System.ComponentModel;
using System.Data;
using System.Text.Json;
using McpSqlServer.Services;
using Microsoft.Data.SqlClient;
using ModelContextProtocol.Server;

namespace McpSqlServer.Tools;

[McpServerToolType]
public class SqlServerTools
{
    private readonly SqlConnectionFactory _connectionFactory;
    private readonly QueryValidator _queryValidator;

    public SqlServerTools(SqlConnectionFactory connectionFactory, QueryValidator queryValidator)
    {
        _connectionFactory = connectionFactory;
        _queryValidator = queryValidator;
    }

    [McpServerTool, Description("Lists all accessible databases on the SQL Server instance.")]
    public async Task<string> ListDatabases(CancellationToken cancellationToken = default)
    {
        await using var conn = _connectionFactory.CreateConnection();
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(@"
            SELECT name, database_id, create_date
            FROM sys.databases
            WHERE state = 0
            ORDER BY name", conn);

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    [McpServerTool, Description("Lists all tables in a database with estimated row counts.")]
    public async Task<string> ListTables(
        [Description("Database name")] string databaseName,
        CancellationToken cancellationToken = default)
    {
        await using var conn = _connectionFactory.CreateConnection(databaseName);
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(@"
            SELECT
                s.name AS schema_name,
                t.name AS table_name,
                p.rows AS row_count
            FROM sys.tables t
            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            LEFT JOIN (
                SELECT object_id, SUM(rows) AS rows
                FROM sys.partitions
                WHERE index_id IN (0,1)
                GROUP BY object_id
            ) p ON t.object_id = p.object_id
            ORDER BY s.name, t.name", conn);

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    [McpServerTool, Description("Returns detailed schema for a table: columns, types, nullability, primary keys, identity.")]
    public async Task<string> DescribeTable(
        [Description("Database name")] string databaseName,
        [Description("Table name")] string tableName,
        [Description("Schema name (default: dbo)")] string? schemaName = "dbo",
        CancellationToken cancellationToken = default)
    {
        await using var conn = _connectionFactory.CreateConnection(databaseName);
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(@"
            SELECT
                c.column_id,
                c.name AS column_name,
                TYPE_NAME(c.user_type_id) AS data_type,
                c.max_length,
                c.precision,
                c.scale,
                c.is_nullable,
                c.is_identity,
                COLUMNPROPERTY(c.object_id, c.name, 'IsComputed') AS is_computed,
                OBJECT_DEFINITION(c.default_object_id) AS default_definition,
                CASE WHEN pk.column_id IS NOT NULL THEN 1 ELSE 0 END AS is_primary_key
            FROM sys.columns c
            INNER JOIN sys.tables t ON c.object_id = t.object_id
            INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
            LEFT JOIN (
                SELECT ic.column_id, ic.object_id
                FROM sys.indexes i
                INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
                WHERE i.is_primary_key = 1
            ) pk ON c.object_id = pk.object_id AND c.column_id = pk.column_id
            WHERE t.name = @tableName AND s.name = @schemaName
            ORDER BY c.column_id", conn);

        cmd.Parameters.AddWithValue("@tableName", tableName);
        cmd.Parameters.AddWithValue("@schemaName", schemaName ?? "dbo");

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    [McpServerTool, Description("Lists all views in a database.")]
    public async Task<string> ListViews(
        [Description("Database name")] string databaseName,
        CancellationToken cancellationToken = default)
    {
        await using var conn = _connectionFactory.CreateConnection(databaseName);
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(@"
            SELECT
                s.name AS schema_name,
                v.name AS view_name,
                v.create_date,
                v.modify_date
            FROM sys.views v
            INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
            ORDER BY s.name, v.name", conn);

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    [McpServerTool, Description("Returns foreign key relationships for a table.")]
    public async Task<string> GetForeignKeys(
        [Description("Database name")] string databaseName,
        [Description("Table name")] string tableName,
        CancellationToken cancellationToken = default)
    {
        await using var conn = _connectionFactory.CreateConnection(databaseName);
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(@"
            SELECT
                fk.name AS constraint_name,
                OBJECT_SCHEMA_NAME(fk.parent_object_id) AS schema_name,
                OBJECT_NAME(fk.parent_object_id) AS table_name,
                COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS column_name,
                OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema_name,
                OBJECT_NAME(fk.referenced_object_id) AS referenced_table_name,
                COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS referenced_column_name
            FROM sys.foreign_keys fk
            INNER JOIN sys.foreign_key_columns fkc
                ON fk.object_id = fkc.constraint_object_id
            WHERE OBJECT_NAME(fk.parent_object_id) = @tableName
            ORDER BY fk.name, fkc.constraint_column_id", conn);

        cmd.Parameters.AddWithValue("@tableName", tableName);

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    [McpServerTool, Description("Executes a custom SELECT query against the database. Only SELECT statements are allowed.")]
    public async Task<string> ExecuteQuery(
        [Description("Database name")] string databaseName,
        [Description("SQL query (SELECT only)")] string query,
        CancellationToken cancellationToken = default)
    {
        _queryValidator.Validate(query);

        await using var conn = _connectionFactory.CreateConnection(databaseName);
        await conn.OpenAsync(cancellationToken);

        var cmd = new SqlCommand(query, conn);
        cmd.CommandType = CommandType.Text;

        var results = await ExecuteReader(cmd, cancellationToken);
        return JsonSerializer.Serialize(results);
    }

    private static async Task<List<Dictionary<string, object?>>> ExecuteReader(
        SqlCommand cmd,
        CancellationToken ct)
    {
        var results = new List<Dictionary<string, object?>>();

        await using var reader = await cmd.ExecuteReaderAsync(ct);
        var columns = reader.GetColumnSchema();

        while (await reader.ReadAsync(ct))
        {
            var row = new Dictionary<string, object?>();
            for (int i = 0; i < columns.Count; i++)
            {
                var value = reader.IsDBNull(i) ? null : reader.GetValue(i);
                row[columns[i].ColumnName] = value;
            }
            results.Add(row);
        }

        return results;
    }
}
