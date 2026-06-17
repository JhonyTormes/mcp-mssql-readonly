using Microsoft.Data.SqlClient;

namespace McpSqlServer.Services;

public class SqlConnectionFactory
{
    private readonly string _connectionString;

    public SqlConnectionFactory()
    {
        _connectionString = Environment.GetEnvironmentVariable("MSSQL_CONNECTION_STRING")
            ?? throw new InvalidOperationException(
                "Environment variable MSSQL_CONNECTION_STRING is not set.");
    }

    public SqlConnection CreateConnection(string? databaseName = null)
    {
        if (string.IsNullOrEmpty(databaseName))
            return new SqlConnection(_connectionString);

        var builder = new SqlConnectionStringBuilder(_connectionString)
        {
            InitialCatalog = databaseName
        };

        return new SqlConnection(builder.ConnectionString);
    }
}
