# SSH, Telnet, Finger, rsync, and TFTP

## SSH: 22
```bash
ssh-keyscan -T 5 <IP>
ssh -v <USER>@<IP>
chmod 600 <key-file>; ssh -i <key-file> <USER>@<IP>
```

## Telnet and Finger: 23, 79
```bash
nc -nv <IP> 23
finger @<IP>
finger <USER>@<IP>
```
- Empty finger output is inconclusive.

## rsync daemon: 873
```bash
rsync rsync://<IP>/
rsync rsync://<IP>/<MODULE>/
rsync rsync://<IP>/<MODULE>/<FILE> ./
```
- Hidden/authenticated modules may not list.

## TFTP: 69/UDP
No listing; request a known filename.

```bash
curl -o <local-file> 'tftp://<IP>/<FILE>'
```
