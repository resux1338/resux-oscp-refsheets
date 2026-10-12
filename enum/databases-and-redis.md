# Databases and Redis

SQLi context: [web/manual-sqli.md](../web/manual-sqli.md)

## MySQL: 3306
```bash
mysql -h <IP> -u <USER> -p
```
```sql
SELECT USER(), CURRENT_USER(), @@version, @@secure_file_priv;
SHOW GRANTS;
SHOW DATABASES;
```
- `USER()` = supplied login; `CURRENT_USER()` = privilege account.
- File access needs `FILE` + permissive `secure_file_priv`.

## PostgreSQL: 5432
```bash
psql -h <IP> -U <USER> -d <DATABASE>
```
```text
\conninfo
\l
\du
\dt
```
```sql
SELECT current_user, version();
```
- `\dt` covers the current search path only; check other schemas.

## MSSQL: 1433
Full workflow: [mssql.md](mssql.md). SQLi: [manual-sqli.md](../web/manual-sqli.md#mssql)

```bash
impacket-mssqlclient '<USER>:<PW>@<IP>' -windows-auth
```
```sql
SELECT SYSTEM_USER;
SELECT DB_NAME();
SELECT IS_SRVROLEMEMBER('sysadmin');
EXEC sp_linkedservers;
```
- `-windows-auth` only for Windows logins.

## Redis: 6379
```bash
redis-cli -h <IP> -p 6379
```
```text
PING
ACL WHOAMI
INFO server
SCAN 0
TYPE <KEY>
GET <KEY>
```
- Repeat `SCAN` until cursor `0`; `TYPE` before `GET`; avoid `KEYS *` on large DBs.
