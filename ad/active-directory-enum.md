# Active Directory enumeration

Note `<DOMAIN.TLD>`, `<DOMAIN>`, `<DC-IP>`, `<DC-FQDN>`, the credential type. Repeat the useful checks after every new credential.

## Domain picture
```bash
ip route get <DC-IP>
dig @<DC-IP> <DOMAIN.TLD> SOA +short
dig @<DC-IP> _ldap._tcp.dc._msdcs.<DOMAIN.TLD> SRV +short
nmap -Pn -sV -p 53,88,135,139,389,445,464,636,3268,3269,3389,5985,5986 <DC-IP>
nxc smb <DC-IP>
```
- Kerberos failures: FQDN, DNS server, clock first → [kerberos-troubleshooting](kerberos-troubleshooting.md).

## No credentials / guest
```bash
nxc smb <DC-IP> -u '' -p '' --shares --users --groups --pass-pol
nxc smb <DC-IP> -u guest -p '' --shares
rpcclient -U '' -N <DC-IP> -c 'enumdomusers; enumdomgroups; getdompwinfo'
smbclient -N -L //<DC-IP>
kerbrute userenum -d <DOMAIN.TLD> --dc <DC-IP> <USER-LIST>
```
- A rejected null session does not mean authenticated enumeration will fail.
- `kerbrute userenum` uses requests without pre-auth, so it doesn't count as a password failure, but it still logs events. Not in Kali's repos: use the release binary.

## Known credential from Kali
```bash
nxc smb <DC-IP> -d <DOMAIN> -u <USER> -p '<PW>' --shares --users --groups --pass-pol
nxc smb <DC-IP> -d <DOMAIN> -u <USER> -p '<PW>' --rid-brute
nxc smb <SUBNET>/24 -d <DOMAIN> -u <USER> -p '<PW>' --shares
ldapdomaindump -u '<DOMAIN>\\<USER>' -p '<PW>' -o <OUTPUT-DIR> <DC-IP>
```
- Read user descriptions, custom groups, computer OS, password / lockout policy, every non-default share. Record where each credential authenticates and whether it is local admin.

## From a domain Windows shell
```cmd
whoami /all
set USERDOMAIN
set USERDNSDOMAIN
set LOGONSERVER
nltest /dsgetdc:<DOMAIN.TLD>
nltest /dclist:<DOMAIN.TLD>
nltest /domain_trusts
net accounts /domain
net user /domain
net group /domain
net group "Domain Admins" /domain
net view /domain
```
```powershell
[System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
([adsi]'').distinguishedName
Get-ChildItem "\\<DC-FQDN>\SYSVOL\<DOMAIN.TLD>\Policies" -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName
```

## PowerView
Full reference → [powerview](powerview.md).
```powershell
. .\PowerView.ps1
Get-Domain
Get-DomainController
Get-DomainPolicyData
Get-DomainUser | Select-Object samaccountname,description,pwdlastset,lastlogon
Get-DomainUser -SPN | Select-Object samaccountname,serviceprincipalname
Get-DomainUser -PreauthNotRequired | Select-Object samaccountname,useraccountcontrol
Get-DomainGroup -Identity '*admin*' | Select-Object samaccountname,description
Get-DomainGroupMember -Identity 'Domain Admins' -Recurse
Get-DomainComputer | Select-Object dnshostname,operatingsystem,operatingsystemversion
Get-DomainTrust
Get-DomainGPO | Select-Object displayname,name
Get-DomainOU | Select-Object name,distinguishedname,gplink
Find-DomainShare -CheckShareAccess
Find-LocalAdminAccess
Find-InterestingDomainAcl -ResolveGUIDs
Get-NetSession -ComputerName <FQDN> -Verbose
```
- Session calls can be incomplete: empty / denied ≠ nobody logged on.

## BloodHound and AD CS
```bash
bloodhound-ce-python -u <USER> -p '<PW>' -d <DOMAIN.TLD> -ns <DC-IP> -c Default --zip
nxc ldap <DC-IP> -d <DOMAIN> -u <USER> -p '<PW>' --bloodhound -c all --dns-server <DC-IP>
```
```powershell
.\SharpHound.exe -c Default --zipfilename <DOMAIN>-enum.zip
```
```bash
certipy find -u '<USER>@<DOMAIN.TLD>' -p '<PW>' -dc-ip <DC-IP> -vulnerable -stdout
```
- Match the collector to the BloodHound edition (CE vs Legacy). `-c All` contacts many hosts: read the collector help first.
- Mark controlled principals as owned; check shortest paths + direct rights → [bloodhound](bloodhound.md). `certipy find` only enumerates → [adcs](adcs.md).
- Local host baseline on each Windows foothold → [windows/enumeration](../windows/enumeration.md), [PowerUp](../windows/enumeration.md#powerup-enumeration-only).

## Triage
| Signal | Confirm | Notes |
| --- | --- | --- |
| Password or clue in a description | Account state, scope, lockout | [authentication](authentication.md) |
| User-backed SPN / pre-auth disabled | Account, SPN, encryption | [authentication](authentication.md) |
| MSSQL SPN / listener / connection string | Instance, login type, SQL rights, links | [mssql](../enum/mssql.md) |
| Readable share / SYSVOL file | Contents, intended reader | [spn-acl-shares](spn-acl-shares.md) |
| Local admin / useful session | Host, service, route | [ldap-and-sessions](ldap-and-sessions.md) · [lateral-movement](lateral-movement.md) |
| Interesting object ACL | Principal, right, target, inheritance | [object-rights](object-rights.md) |
| GPO relationship | Right on GPO, linked scope | [gpo-edges](gpo-edges.md) |
| Enrollment service / template | Enrollment rights, template settings | [adcs](adcs.md) |
| Delegation attribute / descriptor | Direction, controlled SPN, allowed SPN/SIDs | [delegation](delegation.md) |
| LAPS / gMSA lead | Read / decrypt right, scope | [managed-credentials](managed-credentials.md) |
| DNS / operator group membership | DC scope, token, operation, trigger | [privileged-groups](privileged-groups.md) |
| Live NTLM authentication | Signing / binding, destination rights | [ntlm-relay](ntlm-relay.md) |
| BloodHound path | Every edge, by hand | [bloodhound](bloodhound.md) |

## Where is the flag?
→ [windows flag locations](../windows/enumeration.md#where-is-the-flag). Record hostname + full path with each value on an AD set.
