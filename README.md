> **📖 Leia em português:** [README.pt-BR.md](README.pt-BR.md)

# mcp-mssql-readonly

A **read-only** MCP (Model Context Protocol) server for Microsoft SQL Server.

Designed to let AI agents safely explore database schemas and query records — **without any risk of modifying data or structure**. Every query is validated to ensure only `SELECT` statements are executed; DML/DDL commands are blocked at the code level, and the database user itself has restricted read-only permissions.

Built with [.NET 8](https://dotnet.microsoft.com/download/dotnet/8.0) and the official [MCP C# SDK](https://www.nuget.org/packages/ModelContextProtocol).

## Features

| Tool | Description |
|---|---|
| `list_databases` | Lists all accessible databases on the server |
| `list_tables` | Lists all tables in a database with estimated row counts |
| `describe_table` | Returns detailed column info: types, nullability, PKs, identity, defaults |
| `list_views` | Lists all views in a database |
| `get_foreign_keys` | Returns foreign key relationships for a table |
| `execute_query` | Executes a custom SELECT query (validated, read-only) |

## Quick start (recommended)

Run directly with `npx` — no installation, no .NET SDK required:

```bash
npx -y mcp-mssql-readonly
```

Set the connection string via environment variable:

```bash
# Windows (PowerShell)
$env:MSSQL_CONNECTION_STRING = "Server=localhost;Database=MyDatabase;User Id=mcp_readonly;Password=YourPassword;TrustServerCertificate=True;"

# Linux / macOS
export MSSQL_CONNECTION_STRING="Server=localhost;Database=MyDatabase;User Id=mcp_readonly;Password=YourPassword;TrustServerCertificate=True;"

# Then run
npx -y mcp-mssql-readonly
```

## Security

This server enforces read-only access in **two independent layers**:

1. **Code-level validation** — The `QueryValidator` parses every query, strips comments, and rejects any statement that is not a `SELECT` or `WITH` (CTE). Keywords like `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `TRUNCATE`, `EXEC`, `MERGE`, and others are blocked before they reach the database.

2. **Database-level permissions** — The SQL Server login used by this MCP server should be created with minimal privileges: `db_datareader` + `VIEW DEFINITION`. A setup script is provided in `scripts/create_readonly_user.sql`.

## Setup

### 1. Database user

Run `scripts/create_readonly_user.sql` in SQL Server Management Studio to create the `mcp_readonly` login with minimal permissions.

### 2. Install from npm

```bash
npm install -g mcp-mssql-readonly
```

Or run directly without installing:

```bash
npx -y mcp-mssql-readonly
```

## Usage with MCP clients

### OpenCode

```jsonc
{
  "mcp": {
    "mssql": {
      "type": "local",
      "command": ["npx", "-y", "mcp-mssql-readonly"],
      "enabled": true,
      "environment": {
        "MSSQL_CONNECTION_STRING": "Server=...;Database=...;User Id=mcp_readonly;Password=...;TrustServerCertificate=True;"
      }
    }
  }
}
```

### Claude Desktop / Claude Code

```json
{
  "mcpServers": {
    "mssql": {
      "command": "npx",
      "args": ["-y", "mcp-mssql-readonly"],
      "env": {
        "MSSQL_CONNECTION_STRING": "Server=...;Database=...;User Id=mcp_readonly;Password=...;TrustServerCertificate=True;"
      }
    }
  }
}
```

## Testing with MCP Inspector

```bash
npx @modelcontextprotocol/inspector npx -y mcp-mssql-readonly
```

## Building from source

If you want to build the self-contained binary yourself:

```bash
# Prerequisites: .NET 8 SDK
git clone https://github.com/JhonyTormes/mcp-mssql-readonly.git
cd mcp-mssql-readonly

# Build (generates build/McpSqlServer.exe)
dotnet publish src/McpSqlServer/McpSqlServer.csproj \
    -c Release \
    --self-contained true \
    -r win-x64 \
    -o build \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true

# Run directly
./build/McpSqlServer.exe
```

## License

[MIT](LICENSE)
