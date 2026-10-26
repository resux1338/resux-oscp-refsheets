# Remote login checks

## SSH
```bash
ssh <USER>@<IP>
ssh -i <key-file> <USER>@<IP>
```
- Fails → key mode (`chmod 600`), username, accepted auth methods.

## RDP
```bash
nxc rdp <IP> -u <USER> -p '<PW>'
xfreerdp3 /v:<IP> /u:<USER> /p:'<PW>' /cert:ignore +clipboard /dynamic-resolution
xfreerdp3 /v:<IP> /u:<USER> /pth:<NT> /cert:ignore +clipboard
xfreerdp3 /v:<IP> /u:<USER> /p:'<PW>' /drive:share,/tmp /cert:ignore
```
- `/pth:<NT>` needs Restricted Admin mode enabled on the target (`reg add "HKLM\System\CurrentControlSet\Control\Lsa" /v DisableRestrictedAdmin /t REG_DWORD /d 0 /f`); full chain: [lateral-movement](../ad/lateral-movement.md#rdp-with-a-hash).
- `/drive:<name>,<local-path>`: mounts `<local-path>` inside the session as a drive named `<name>`. Two-way file transfer without a separate upload step.
- Black screen → VPN route/MTU.

### Enable RDP (already admin, no GUI)
```cmd
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=Yes
net localgroup "Remote Desktop Users" <USER> /add
```
- `fDenyTSConnections=0` enables RDP but doesn't open the firewall. Both commands are needed.
- Non-admin group members (`Remote Desktop Users`) still need RDP enabled by an admin first; the group alone doesn't do that.

## WinRM
```bash
nxc winrm <IP> -u <USER> -p '<PW>'
evil-winrm -i <IP> -u <USER> -p '<PW>'
evil-winrm -i <IP> -u <USER> -H <NT>
evil-winrm -i <IP> -u <USER> -p '<PW>' -s /path/to/ps-scripts/ -e /path/to/exes/
evil-winrm -i <FQDN> -r <DOMAIN.TLD>
```
- NT hash works (NTLM). NetNTLMv2 is crack-only: [cracking](../passwords/cracking.md#identify-the-hash).
- `-s`/`-e`: local directories of PowerShell scripts / C# executables, loaded into the session. Inside the shell: `upload <local> <remote>`, `download <remote> <local>`, `menu` (lists what `-s`/`-e` made available), `Bypass-4MSI` (AMSI bypass before running something that would otherwise be flagged).
- `-r`: Kerberos auth with the ticket in `KRB5CCNAME`; needs the realm in `/etc/krb5.conf` (`<DOMAIN.TLD> = { kdc = <DC-FQDN> }`, full file: [krb5.conf](../ad/kerberos-troubleshooting.md#minimal-krb5conf-for-kinit-evil-winrm--r-ssh-with-gssapi)) and `-i` as the target's FQDN, not a bare IP.

## SSH: legacy algorithms
Old box, modern Kali OpenSSH refuses the handshake:
```bash
ssh <USER>@<IP> -oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa
ssh <USER>@<IP> -oKexAlgorithms=+diffie-hellman-group1-sha1 -oHostKeyAlgorithms=+ssh-rsa -oCiphers=+aes128-cbc
```
- `+` appends to the default list instead of replacing it. `no matching key exchange method found` names the missing algorithm: add exactly that one.
