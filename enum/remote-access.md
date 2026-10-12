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
```
- Black screen → VPN route/MTU.

## WinRM
```bash
nxc winrm <IP> -u <USER> -p '<PW>'
evil-winrm -i <IP> -u <USER> -p '<PW>'
evil-winrm -i <IP> -u <USER> -H <NT>
```
- NT hash works (NTLM). NetNTLMv2 is crack-only: [cracking](../passwords/cracking.md#identify-the-hash).
