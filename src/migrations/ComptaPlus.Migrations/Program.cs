using System;
using System.IO;
using DbUp;

static string MustGet(string name)
{
    var v = Environment.GetEnvironmentVariable(name);
    if (string.IsNullOrWhiteSpace(v))
        throw new InvalidOperationException($"Missing env var: {name}");
    return v.Trim();
}

static string GetOrDefault(string name, string fallback)
{
    var v = Environment.GetEnvironmentVariable(name);
    return string.IsNullOrWhiteSpace(v) ? fallback : v.Trim();
}

static string BuildSqlAuthConnectionString(string fqdn, string dbName, string login, string password) =>
    $"Server=tcp:{fqdn},1433;Database={dbName};User ID={login};Password={password};" +
    "Encrypt=True;TrustServerCertificate=False;" +
    // Make transient post-login stalls much less painful (GitHub-hosted runners + firewall propagation)
    "Connection Timeout=120;ConnectRetryCount=5;ConnectRetryInterval=10;";

static int RunDb(string dbLabel, string connectionString, string scriptsDir)
{
    if (!Directory.Exists(scriptsDir))
        throw new DirectoryNotFoundException($"Scripts directory not found: {scriptsDir}");

    Console.WriteLine($"--- DbUp: {dbLabel} ---");
    Console.WriteLine($"Scripts: {scriptsDir}");

    var upgrader =
        DeployChanges.To
            .SqlDatabase(connectionString)
            .JournalToSqlTable("dbo", "__schema_migrations")
            .WithScriptsFromFileSystem(scriptsDir) // filename order
            .LogToConsole()
            .Build();

    var result = upgrader.PerformUpgrade();

    if (!result.Successful)
    {
        Console.Error.WriteLine(result.Error);
        return 1;
    }

    Console.WriteLine($"DbUp OK: {dbLabel}");
    return 0;
}

try
{
    var fqdn = MustGet("SQL_SERVER_FQDN");
    var coreDb = MustGet("CORE_DB_NAME");
    var dirDb = MustGet("DIRECTORY_DB_NAME");

    var migrationsRoot = GetOrDefault(
        "MIGRATIONS_ROOT",
        Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "..", "..", "db", "migrations"))
    );

    var login = GetOrDefault("SQL_ADMIN_LOGIN", "sqladmin");
    var password = MustGet("SQL_ADMIN_PASSWORD");

    var dirScripts = Path.Combine(migrationsRoot, "directory");
    var coreScripts = Path.Combine(migrationsRoot, "core");

    var dirConn = BuildSqlAuthConnectionString(fqdn, dirDb, login, password);
    var coreConn = BuildSqlAuthConnectionString(fqdn, coreDb, login, password);

    var exit1 = RunDb("directory", dirConn, dirScripts);
    if (exit1 != 0) Environment.Exit(exit1);

    Environment.Exit(RunDb("core", coreConn, coreScripts));
}
catch (Exception ex)
{
    Console.Error.WriteLine(ex);
    Environment.Exit(1);
}
