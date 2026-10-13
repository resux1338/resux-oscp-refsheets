# Service triage

Fingerprinting workflow: [web/fingerprinting.md](../web/fingerprinting.md)

| Port | Topic | First check |
| --- | --- | --- |
| 21 | [FTP](ftp.md) | Anonymous login, readable files |
| 22, 23, 79 | [SSH, Telnet, Finger](other-services.md) | Banner, host key, users |
| 25, 465, 587 | [SMTP](mail.md#smtp-25-465-587) | EHLO, recipient policy |
| 53 | [DNS](dns.md) | Records, zone transfer |
| 69/UDP, 873 | [TFTP, rsync](other-services.md) | Known file, rsync modules |
| 80, 443, 8080 | [Web](../web/web-enumeration.md) | Hostname, headers, paths, source |
| 110, 995, 143, 993 | [POP3, IMAP](mail.md) | Mailbox listing with creds |
| 111, 2049 | [NFS](nfs.md) | Exports, read-only mount |
| 135, 139, 445 | [SMB, RPC](smb.md) | Null/guest shares, signing |
| 161/UDP | [SNMP](snmp.md) | Community, targeted OIDs |
| 88 | [Kerberos](../ad/active-directory-enum.md) | Domain controller: user enum, roasting |
| 389, 636, 3268 | [LDAP](exposed-services.md#ldap-389-636-3268) · [AD](../ad/ldap-and-sessions.md) | Naming context, anonymous search |
| 623/UDP | [IPMI](exposed-services.md#ipmi-623udp) | Version, cipher zero, user hash |
| 1433, 3306, 5432, 6379 | [Databases, Redis](databases-and-redis.md) | Login, role, data → [RCE paths](databases-and-redis.md#from-database-access-to-code-execution) |
| 1521 | [Oracle TNS](exposed-services.md#oracle-tns-1521) | SID, default account |
| 2375 | [Docker API](exposed-services.md#docker-api-2375-2376-tls) | `/version`, container run |
| 3389, 5985, 5986 | [Remote access](remote-access.md) | RDP/WinRM login, rights |
| 5900 | [VNC](exposed-services.md#vnc-5900) | Security type, password |
| 8009 | [AJP](exposed-services.md#ajp-8009-tomcat) | Tomcat version, Ghostcat |
| 9200 | [Elasticsearch](exposed-services.md#elasticsearch-9200) | Indices, version |
| 11211 | [memcached](exposed-services.md#memcached-11211) | `stats items`, keys |
| 27017 | [MongoDB](exposed-services.md#mongodb-27017) | Unauthenticated `show dbs` |
| 8080, 8443, 8000+ | [Web apps](../web/cms-and-apps.md) | Tomcat, Jenkins, CMS, exposed `.git` |

```powershell
Test-NetConnection -ComputerName <IP> -Port 445
```
