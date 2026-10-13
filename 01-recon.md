# 01 · Recon & Enumeration

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Full TCP scan → service checks. Record names, ports, working credentials.

```bash
nmap -Pn -p- -T3 <IP>
```

[Scan tuning and UDP](enum/network-scanning.md) · [Port-to-service index](enum/service-triage.md)

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Scan looks empty | `ip route get <IP>`, slower rate, selected UDP | [Network scanning](enum/network-scanning.md) |
| Unknown service | `nmap -sC -sV` on the port; banner, TLS | [Service triage](enum/service-triage.md) |
| Hostname or vhost | Compare IP vs hostname response | [Web enumeration](web/web-enumeration.md) · [DNS](enum/dns.md) |
| Anonymous files | One anonymous/guest login; list shares | [SMB](enum/smb.md) · [FTP](enum/ftp.md) · [NFS](enum/nfs.md) |
| Information in a service | SNMP, mail, unauthenticated RPC | [SNMP](enum/snmp.md) · [Mail](enum/mail.md) · [Other services](enum/other-services.md) |
| Database or cache | Test found account; check role, data | [Databases and Redis](enum/databases-and-redis.md) · [RCE paths](enum/databases-and-redis.md#from-database-access-to-code-execution) |
| Uncommon port | Banner, auth required, data readable | [Less common services](enum/exposed-services.md) |
| Web app | Source, JS, paths, vhosts first | [Web enumeration](web/web-enumeration.md) · [Fingerprinting](web/fingerprinting.md) · [Foothold](02-foothold.md) |
| Remote login | Known account vs matching service | [RDP and WinRM](enum/remote-access.md) |
| Domain controller | Resolve domain name; LDAP, SMB, Kerberos | [AD](05-active-directory.md) |

Repeat service checks with each new credential.
