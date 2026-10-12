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
| 389, 636 | [LDAP](../ad/ldap-and-sessions.md) | Naming context, objects |
| 1433, 3306, 5432, 6379 | [Databases, Redis](databases-and-redis.md) | Login, role, data |
| 3389, 5985, 5986 | [Remote access](remote-access.md) | RDP/WinRM login, rights |

```powershell
Test-NetConnection -ComputerName <IP> -Port 445
```
