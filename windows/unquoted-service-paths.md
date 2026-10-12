# Unquoted service paths

Needs: unquoted path with spaces + writable `<prefix>.exe` + privileged service + trigger.

| `PathName` | Candidates |
| --- | --- |
| `C:\Program Files\Acme Tools\agent.exe` | `C:\Program.exe`, `C:\Program Files\Acme.exe` |
| `C:\Apps\Team Tools\Service Agent\svc.exe` | `C:\Apps\Team.exe`, `C:\Apps\Team Tools\Service.exe` |

```powershell
Get-CimInstance -ClassName Win32_Service |
  Where-Object { $_.PathName -match '^[^"].*\s.*\.exe' -and $_.PathName -notmatch 'C:\\Windows' } |
  Select-Object Name, StartName, State, PathName

Test-Path 'C:\Program.exe'
icacls 'C:\'
icacls 'C:\Program Files'
Test-Path 'C:\Apps\Team Tools\Service.exe'
icacls 'C:\Apps\Team Tools'
sc.exe query <SERVICE>
```
- Read `PathName` and arguments by hand; do not overwrite an existing prefix file.
- Test the exact path, then remove your file.

PowerUp discovery:
```powershell
. .\PowerUp.ps1
Get-UnquotedService
```
