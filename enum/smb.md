# SMB and RPC

## Shares (null / guest first, then creds)
```bash
smbclient -L //<IP>/ -U '' -N
nxc smb <IP> -u '' -p '' --shares
nxc smb <IP> -u 'guest' -p '' --shares
enum4linux-ng -A <IP>
smbmap -H <IP>                # null session (no -u)
smbmap -H <IP> -u null        # bogus user → guest, if enabled
```

## Open a share
```bash
smbclient //<IP>/<SHARE> -U '<DOMAIN>/<USER>'
smbclient //<IP>/<SHARE> -U '<DOMAIN>/<USER>' -c 'ls; get notes.txt'
```
- Inside: `pwd`, `ls`, `cd`, `get`, `put` (test write). Check `SYSVOL`.
- AD shares/ACLs: [ad/spn-acl-shares.md](../ad/spn-acl-shares.md)

## RPC null session
```bash
rpcclient -U '' -N <IP> -c 'enumdomusers'
rpcclient -U '' -N <IP> -c 'enumdomgroups'
nxc smb <IP> -u <USER> -p '<PW>' --rid-brute
```

## SMB signing (relay target check)
```bash
nmap -p445 --script smb2-security-mode <IP>
```

## Download a share
```bash
smbclient //<IP>/<SHARE> -U '<DOMAIN>/<USER>' -c 'recurse ON; prompt OFF; mget *'
nxc smb <IP> -u '<USER>' -p '<PW>' -M spider_plus
nxc smb <IP> -u '<USER>' -p '<PW>' -M spider_plus --options
```
- `spider_plus` writes a JSON index of every readable share (path shown in the output); `--options` lists the download switch.
- `mget *` runs in the current share directory; `recurse ON` follows subdirectories.

## Mount a share
```bash
sudo mkdir -p /mnt/smb
sudo mount -t cifs //<IP>/<SHARE> /mnt/smb -o username=<USER>,password='<PW>',ro
sudo mount -t cifs //<IP>/<SHARE> /mnt/smb -o guest,ro
find /mnt/smb -type f -ls
sudo umount /mnt/smb
```
- Drop `ro` to test write. Old server → add `vers=1.0` / `vers=2.0`; SMB1 may need to be enabled client-side.
