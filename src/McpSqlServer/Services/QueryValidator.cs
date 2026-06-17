using System.Text.RegularExpressions;

namespace McpSqlServer.Services;

public class QueryValidator
{
    private static readonly string[] BlockedPatterns =
    [
        @"\bINSERT\b",
        @"\bUPDATE\b",
        @"\bDELETE\b",
        @"\bDROP\b",
        @"\bALTER\b",
        @"\bCREATE\b",
        @"\bTRUNCATE\b",
        @"\bEXEC\b",
        @"\bEXECUTE\b",
        @"\bMERGE\b",
        @"\bGRANT\b",
        @"\bREVOKE\b",
        @"\bRESTORE\b",
        @"\bBACKUP\b",
        @"\bRECONFIGURE\b",
        @"\bSHUTDOWN\b",
        @"\bKILL\b",
    ];

    public void Validate(string query)
    {
        var cleanQuery = RemoveComments(query);

        if (!StartsWithSelectOrWith(cleanQuery))
            throw new InvalidOperationException(
                "Only SELECT queries are allowed. DML/DDL commands are not accepted.");

        foreach (var pattern in BlockedPatterns)
        {
            if (Regex.IsMatch(cleanQuery, pattern, RegexOptions.IgnoreCase))
                throw new InvalidOperationException(
                    "Query rejected by security validation: blocked command detected.");
        }
    }

    private static string RemoveComments(string sql)
    {
        sql = Regex.Replace(sql, @"/\*.*?\*/", "", RegexOptions.Singleline);
        sql = Regex.Replace(sql, @"--.*?$", "", RegexOptions.Multiline);
        return sql;
    }

    private static bool StartsWithSelectOrWith(string sql)
    {
        var trimmed = sql.TrimStart();
        if (trimmed.Length == 0) return false;

        if (trimmed.StartsWith("SELECT", StringComparison.OrdinalIgnoreCase))
            return true;

        if (trimmed.StartsWith("WITH", StringComparison.OrdinalIgnoreCase))
            return true;

        return false;
    }
}
