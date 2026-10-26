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
- AD shares/SYSVOL: [ad/spn-acl-shares.md](../ad/spn-acl-shares.md). Object ACLs: [ad/object-rights.md](../ad/object-rights.md).

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

## Auth with a hash or a Kerberos ticket
```bash
smbclient //<IP>/<SHARE> -U '<DOMAIN>/<USER>%<NT>' --pw-nt-hash
nxc smb <IP> -u '<USER>' -H '<NT>' --shares
impacket-smbclient -hashes ':<NT>' '<DOMAIN>/<USER>@<IP>'
```
- `--pw-nt-hash`: the value after `%` is read as the NT hash, not a password.
```bash
export KRB5CCNAME=<PATH>.ccache
nxc smb <IP> -k --use-kcache --shares
impacket-smbclient -k -no-pass '<DOMAIN>/<USER>@<IP>'
```

## More nxc enumeration flags
```bash
nxc smb <IP> -u '<USER>' -p '<PW>' --users
nxc smb <IP> -u '<USER>' -p '<PW>' --loggedon-users
nxc smb <IP> -u '<USER>' -p '<PW>' --smb-sessions
nxc smb <IP> -u '<USER>' -p '<PW>' --disks
nxc smb <IP> -u '<USER>' -p '<PW>' --pass-pol
```
- `--shares` output: a `READ` / `WRITE` column per share for the account used — `WRITE` is a drop point, not just a read target.
- `--loggedon-users` usually needs admin on the target for the full list; non-admin often returns nothing.

## RID brute without nxc
```bash
impacket-lookupsid '<DOMAIN>/<USER>:<PW>@<IP>' 10000
impacket-lookupsid -hashes ':<NT>' '<DOMAIN>/<USER>@<IP>'
```

## Other enumeration tools
```bash
smbmap -H <IP> -u '<USER>' -p '<PW>' -r '<SHARE>'
enum4linux -a -u '<USER>' -p '<PW>' <IP>
```
- `smbmap -r [PATH]`: recursive listing (lowercase `-r`; no path lists the root of every share). `--depth` sets how many levels.
- `enum4linux` (classic, Perl): `-a` runs userlist/sharelist/groups/password-policy/OS/RID-cycle in one pass.

## MS17-010 and version check
```bash
nmap -p445 --script smb-vuln-ms17-010 <IP>
nxc smb <IP>
```
- `nxc smb <IP>` prints the OS name and build in its default banner line — no extra flag needed. An old, unpatched build is the cue to run `smb-vuln-ms17-010`.

## Writable share → NetNTLM capture
Drop a `.url`, `.scf`, or `.lnk` file; opening the file, or in some cases just browsing the folder, fires an outbound SMB auth to your listener.
- Generation, listener, cracking: [windows/ntlm-capture.md](../windows/ntlm-capture.md).
