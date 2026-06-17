> **📖 Read in English:** [README.md](README.md)

# mcp-mssql-readonly

Um servidor MCP (Model Context Protocol) **somente leitura** para Microsoft SQL Server.

Projetado para permitir que agentes de IA explorem esquemas de banco de dados e consultem registros com segurança — **sem qualquer risco de modificar dados ou estrutura**. Cada consulta é validada para garantir que apenas instruções `SELECT` sejam executadas; comandos DML/DDL são bloqueados no nível do código, e o próprio usuário do banco de dados tem permissões restritas de somente leitura.

Construído com [.NET 8](https://dotnet.microsoft.com/download/dotnet/8.0) e o [MCP C# SDK](https://www.nuget.org/packages/ModelContextProtocol) oficial.

## Funcionalidades

| Ferramenta | Descrição |
|---|---|
| `list_databases` | Lista todos os bancos de dados acessíveis no servidor |
| `list_tables` | Lista todas as tabelas em um banco de dados com contagem estimada de linhas |
| `describe_table` | Retorna informações detalhadas das colunas: tipos, nulabilidade, chaves primárias, identidade, valores padrão |
| `list_views` | Lista todas as views em um banco de dados |
| `get_foreign_keys` | Retorna relacionamentos de chaves estrangeiras para uma tabela |
| `execute_query` | Executa uma consulta SELECT personalizada (validada, somente leitura) |

## Início rápido (recomendado)

Execute diretamente com `npx` — sem instalação, sem necessidade do .NET SDK:

```bash
npx -y mcp-mssql-readonly
```

Defina a string de conexão via variável de ambiente:

```bash
# Windows (PowerShell)
$env:MSSQL_CONNECTION_STRING = "Server=localhost;Database=MyDatabase;User Id=mcp_readonly;Password=YourPassword;TrustServerCertificate=True;"

# Linux / macOS
export MSSQL_CONNECTION_STRING="Server=localhost;Database=MyDatabase;User Id=mcp_readonly;Password=YourPassword;TrustServerCertificate=True;"

# Depois execute
npx -y mcp-mssql-readonly
```

## Segurança

Este servidor impõe acesso somente leitura em **duas camadas independentes**:

1. **Validação no código** — O `QueryValidator` analisa cada consulta, remove comentários e rejeita qualquer instrução que não seja `SELECT` ou `WITH` (CTE). Palavras-chave como `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`, `CREATE`, `TRUNCATE`, `EXEC`, `MERGE` e outras são bloqueadas antes de chegarem ao banco de dados.

2. **Permissões no banco de dados** — O login do SQL Server usado por este servidor MCP deve ser criado com privilégios mínimos: `db_datareader` + `VIEW DEFINITION`. Um script de configuração está disponível em `scripts/create_readonly_user.sql`.

## Configuração

### 1. Usuário do banco de dados

Execute `scripts/create_readonly_user.sql` no SQL Server Management Studio para criar o login `mcp_readonly` com permissões mínimas.

### 2. Instalar via npm

```bash
npm install -g mcp-mssql-readonly
```

Ou execute diretamente sem instalar:

```bash
npx -y mcp-mssql-readonly
```

## Uso com clientes MCP

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

## Testando com o MCP Inspector

```bash
npx @modelcontextprotocol/inspector npx -y mcp-mssql-readonly
```

## Compilando a partir do código fonte

Se você quiser compilar o binário autossuficiente:

```bash
# Pré-requisitos: .NET 8 SDK
git clone https://github.com/JhonyTormes/mcp-mssql-readonly.git
cd mcp-mssql-readonly

# Compilar (gera build/McpSqlServer.exe)
dotnet publish src/McpSqlServer/McpSqlServer.csproj \
    -c Release \
    --self-contained true \
    -r win-x64 \
    -o build \
    -p:PublishSingleFile=true \
    -p:PublishTrimmed=true

# Executar diretamente
./build/McpSqlServer.exe
```

## Licença

[MIT](LICENSE)
