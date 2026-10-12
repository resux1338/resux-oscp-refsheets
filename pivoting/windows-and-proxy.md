# Windows pivots and proxy checks

## Reachability from the foothold
```powershell
Test-NetConnection -ComputerName <IP> -Port 445
Test-NetConnection -ComputerName <IP> -Port 3389
```

## Forward one TCP port
Plink (Windows SSHes to Kali; internal service appears on Kali loopback):
```cmd
plink.exe -ssh -l <USER> -pw <PW> -R 127.0.0.1:3389:<IP>:3389 <KALI>
```
`netsh portproxy` (admin + IP Helper; listens on the pivot):
```cmd
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=3389 connectaddress=<IP> connectport=3389
netsh interface portproxy show all
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=3389
```
- `<USER>`/`<PW>` for plink = an SSH account on Kali.
- The last line removes the rule.

## Proxychains
```bash
proxychains nmap -sT -Pn -p 445 <IP>
```
- IP works but name fails → DNS / `proxy_dns`.
