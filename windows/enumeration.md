# Windows host enumeration

## First pass
```powershell
whoami
whoami /all
hostname
systeminfo
ipconfig /all
route print
netstat -ano
```
- Administrators SID in the token ≠ elevated: check integrity level and which privileges are enabled.

```powershell
$PSVersionTable
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption,Version,BuildNumber,OSArchitecture,LastBootUpTime
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20
Get-MpComputerStatus
```
- Cmdlet missing → `systeminfo` or the native command. WMIC is removed on current Windows.

## Users, groups, sessions
```cmd
net user
net localgroup
net localgroup Administrators
qwinsta
query user
cmdkey /list
```
```powershell
Get-LocalUser
Get-LocalGroup
Get-LocalGroupMember -Group '<LOCAL-ADMIN-GROUP>'
Get-CimInstance Win32_LoggedOnUser
```
- Non-English host: use the localized Administrators group name.
- Token rights → [token-groups](token-groups.md). Domain/DC groups → [ad/privileged-groups](../ad/privileged-groups.md).

## Processes, software, local services
```powershell
Get-Process
tasklist /svc
Get-NetTCPConnection -State Listen | Sort-Object LocalPort
Get-CimInstance Win32_Service |
    Select-Object Name,State,StartMode,StartName,PathName
```
```powershell
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object DisplayName |
    Select-Object DisplayName,DisplayVersion,Publisher,InstallLocation
```
- Local-only listener: match owning process and account, then [forward it](../06-pivoting.md).

## Services and file permissions
```powershell
Get-CimInstance Win32_Service |
    Where-Object { $_.PathName -and $_.PathName -notmatch '^"?C:\\Windows\\' } |
    Select-Object Name,State,StartName,PathName

sc.exe qc <SERVICE>
sc.exe sdshow <SERVICE>
icacls '<PATH>'
Get-Acl '<PATH>' | Format-List
```
- Unquoted path: needs spaces + a writable candidate prefix → [unquoted-service-paths](unquoted-service-paths.md).
- Writable binary: needs a stronger service account + a trigger → [service-binary-hijacking](service-binary-hijacking.md).
- Service ACL → [service-permissions](service-permissions.md).

## Scheduled tasks, autoruns, installer policy
```powershell
schtasks /query /fo LIST /v
Get-ScheduledTask | Select-Object TaskPath,TaskName,State,Principal,Actions
Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run*',
                 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run*' -ErrorAction SilentlyContinue
```
```cmd
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```
- `AlwaysInstallElevated`: both values must be 1 → [services](services.md#installer-policy).
- Task/autorun: check referenced file + parent-directory ACLs, run-as account, trigger → [scheduled-tasks-and-autoruns](scheduled-tasks-and-autoruns.md).

## Targeted credential checks
```powershell
(Get-PSReadLineOption).HistorySavePath
Get-History
cmdkey /list

reg query 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultUserName
reg query 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' /v DefaultPassword

$SearchRoots = @($env:USERPROFILE, 'C:\inetpub\wwwroot', '<APPLICATION-PATH>')
Get-ChildItem -Path $SearchRoots -Include *.txt,*.ini,*.xml,*.config,*.ps1,*.bat,*.cmd `
    -File -Recurse -ErrorAction SilentlyContinue |
    Select-String -Pattern 'pass(word)?|secret|token|connectionstring|api.?key'

Get-ChildItem 'C:\Windows\Panther','C:\Windows\System32\Sysprep' `
    -Include *unattend*.xml,*sysprep*.xml -File -Recurse -ErrorAction SilentlyContinue
```
- A found value is a candidate until it authenticates → [credentials](credentials.md).

## PowerUp: enumeration only
```powershell
. .\PowerUp.ps1
Invoke-PrivescAudit
# alias in the PowerSploit version:
Invoke-AllChecks

Get-ProcessTokenPrivilege -Special
Get-UnquotedService
Get-ModifiableServiceFile
Get-ModifiableService
Find-PathDLLHijack
Get-RegistryAlwaysInstallElevated
Get-RegistryAutoLogon
Get-ModifiableRegistryAutoRun
Get-ModifiableScheduledTaskFile
Get-UnattendedInstallFile
Get-WebConfig
Get-ApplicationHost
Get-SiteListPassword
Get-CachedGPPPassword
```
- Audit prints the suggested abuse function name but does not run it.
- Verify each hit with `sc.exe`, `icacls`, `Get-Acl`, `reg query`, task details.

## Wider automated sweep
```powershell
.\winPEASany.exe
. .\PrivescCheck.ps1; Invoke-PrivescCheck
.\Seatbelt.exe -group=all
```
- Output is a lead list: confirm the exact right and trigger by hand.
- Kernel/CVE matching last: patch detection is often wrong.
```bash
python3 wes.py systeminfo.txt
```
- `wes.py` (wesng): `wes.py --update` first; feed it saved `systeminfo` output.

## Tool troubleshooting
```powershell
Get-FileHash '<FILE>' -Algorithm SHA256
[System.Environment]::Version
Get-MpComputerStatus
```
- Compare the checksum with the Kali copy, then check .NET runtime, architecture, Defender.

## Triage
| Signal | Confirm | Notes |
| --- | --- | --- |
| Interesting token privilege | Enabled in this token; resource exists | [token-groups](token-groups.md) · [potato](potato.md) |
| Writable service executable | Service account, ACL, restart trigger | [service-binary-hijacking](service-binary-hijacking.md) |
| Modifiable service config | Service right + start/stop ability | [service-permissions](service-permissions.md) |
| Unquoted service path | Prefix exists and is writable | [unquoted-service-paths](unquoted-service-paths.md) |
| Writable task/autorun/DLL path | ACL, privileged consumer, trigger | [scheduled-tasks-and-autoruns](scheduled-tasks-and-autoruns.md) · [dll-hijacking](dll-hijacking.md) |
| Saved credential/config secret | Account scope, accepted logon | [credentials](credentials.md) |
| Local-only service | Process, version, auth, forward | [pivoting](../06-pivoting.md) |

## Where is the flag?
```powershell
Get-ChildItem 'C:\Users\*\Desktop\local.txt','C:\Users\*\Desktop\proof.txt' `
    -Force -ErrorAction SilentlyContinue | Select-Object FullName

Get-ChildItem -Path C:\ -Include local.txt,proof.txt -File -Recurse -Force `
    -ErrorAction SilentlyContinue | Select-Object FullName
```
```cmd
where /r C:\ local.txt 2>nul
where /r C:\ proof.txt 2>nul
type "<FLAG-PATH>"
```
- `local.txt` = user context, `proof.txt` = elevated. Screenshot with hostname + full path.
