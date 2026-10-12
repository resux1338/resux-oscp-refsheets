# SPNs, object rights, and shares

Record principal + right + target + inheritance.

## SPNs
```powershell
Get-NetUser -SPN | Select-Object samaccountname,serviceprincipalname
nslookup.exe <FQDN>
```
```cmd
setspn -L <SERVICE-ACCOUNT>
```

## Object ACLs
```powershell
Get-ObjectAcl -Identity <USER>
Convert-SidToName <SID>
Get-ObjectAcl -Identity '<GROUP>' |
    Where-Object {$_.ActiveDirectoryRights -eq 'GenericAll'} |
    Select-Object SecurityIdentifier,ActiveDirectoryRights
```
- Resolve SIDs. Look for `GenericAll`, `GenericWrite`, `WriteOwner`, `WriteDACL`, `AllExtendedRights`, `ForceChangePassword` on the exact target.
- After `WriteOwner`/`WriteDACL`: save owner + ACL so you can restore them.

## Shares and SYSVOL
```powershell
Find-DomainShare
Get-ChildItem \\<DC-FQDN>\sysvol\<DOMAIN.TLD>\Policies\
Get-ChildItem \\<FQDN>\<SHARE>
```
```bash
gpp-decrypt '<CPASSWORD>'
nxc smb <SUBNET>/24 -u <USER> -p '<PW>' -M spider_plus
manspider <SUBNET>/24 -u <USER> -p '<PW>' -c password
nxc smb <DC-IP> -u <USER> -p '<PW>' -M gpp_password
nxc ldap <DC-IP> -u <USER> -p '<PW>' -M laps
```
- Keep the source path of recovered credentials.
- Writable share/script/plugin needs a privileged load trigger to execute.
