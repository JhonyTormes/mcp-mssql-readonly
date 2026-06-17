using McpSqlServer.Services;
using McpSqlServer.Tools;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton<SqlConnectionFactory>();
builder.Services.AddSingleton<QueryValidator>();
builder.Services.AddMcpServer(options =>
{
    options.ServerInfo = new()
    {
        Name = "McpSqlServer",
        Version = "1.0.0"
    };
})
.WithTools<SqlServerTools>();

await builder.Build().RunAsync();
