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
