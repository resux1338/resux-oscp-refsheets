# PowerView

Windows PowerShell 5.1. Note account + right + target + service.

[Initial enumeration](#initial-enumeration) · [Lateral movement](#lateral-movement) · [Post-exploitation](#post-exploitation)

## Load and scope
```powershell
. .\PowerView.ps1

$Domain = '<DOMAIN.TLD>'
$DC = '<DC-FQDN>'
$Principal = '<USER>'
$DomainDN = ($Domain.Split('.') | ForEach-Object { "DC=$_" }) -join ','
$LDAP = @{ Domain = $Domain; Server = $DC }
$Net = @{}
$Targets = @('<FQDN>', '<FQDN2>')
```
- `@LDAP` = domain/DC arguments; `@Net` = optional credentials for host calls. Default is the current logon.

Another account:
```powershell
$Cred = Get-Credential -UserName '<DOMAIN>\<USER>' -Message 'Domain credential'
$LDAP.Credential = $Cred
$Net.Credential = $Cred
```
- `-Credential` applies per function: native UNC reads need their own network context.

## Initial enumeration

### Domain, DCs, trusts
```powershell
whoami /all
Get-Domain -Domain $Domain @Net | Select-Object Name,Forest,PdcRoleOwner
Get-DomainSID @LDAP
Get-DomainController -LDAP @LDAP |
    Select-Object dnshostname,operatingsystem,distinguishedname
Get-DomainTrust @LDAP |
    Select-Object SourceName,TargetName,TrustDirection,TrustType,TrustAttributes
Get-ForestDomain -Forest '<FOREST-ROOT.TLD>' @Net | Select-Object Name
```
- Trust: direction + selective authentication + SID filtering + route.

### Password and lockout policy
```powershell
(Get-DomainPolicyData -Policy Domain @LDAP).SystemAccess
Get-DomainObject -Identity $DomainDN @LDAP `
    -Properties minpwdlength,pwdhistorylength,lockoutthreshold,lockoutduration,lockoutobservationwindow |
    Format-List

# Fine-grained policy for this user
$PSO = (Get-DomainUser -Identity $Principal @LDAP `
    -Properties 'msDS-ResultantPSO').'msds-resultantpso'
if ($PSO) {
    Get-DomainObject -Identity $PSO @LDAP `
        -Properties name,'msDS-LockoutThreshold','msDS-LockoutDuration','msDS-LockoutObservationWindow' |
        Format-List
}
```
- Check the resultant policy before [password tests](authentication.md). LDAP durations are negative 100 ns intervals.

### Users and groups
```powershell
$Users = Get-DomainUser @LDAP `
    -Properties samaccountname,description,info,pwdlastset,lastlogontimestamp,useraccountcontrol
$Users | Select-Object samaccountname,description,info,pwdlastset,lastlogontimestamp,useraccountcontrol

Get-DomainUser -Identity $Principal @LDAP |
    Select-Object samaccountname,objectsid,memberof,primarygroupid,admincount,badpwdcount
Get-DomainUser -AdminCount @LDAP | Select-Object samaccountname,memberof
Get-DomainGroup @LDAP | Select-Object samaccountname,description
Get-DomainGroup -Identity '*admin*' @LDAP | Select-Object samaccountname,member
Get-DomainGroupMember -Identity '<GROUP>' -Recurse @LDAP |
    Select-Object GroupName,MemberName,MemberSID,MemberDomain
Get-DomainGroup -MemberIdentity $Principal @LDAP |
    Select-Object samaccountname,objectsid
```
- Read descriptions, notes, service ownership, custom groups.
- `memberof` = direct groups, primary group omitted. `-MemberIdentity` = nested groups, skips BUILTIN SIDs.
- `adminCount=1` can be stale. `lastLogonTimestamp` is approximate; `lastLogon` is per queried DC.
- Current shell groups: `whoami /groups`. Sessions → [Sessions](#sessions).

### SPNs and pre-auth
```powershell
Get-DomainUser -SPN -UACFilter NOT_ACCOUNTDISABLE @LDAP |
    Select-Object samaccountname,serviceprincipalname,description,pwdlastset
Get-DomainUser -PreauthNotRequired -UACFilter NOT_ACCOUNTDISABLE @LDAP |
    Select-Object samaccountname,useraccountcontrol
```
- SPN → service account + host/port. No pre-auth → AS-REP ([authentication](authentication.md)).

### Computers
```powershell
$Computers = Get-DomainComputer @LDAP `
    -Properties dnshostname,operatingsystem,operatingsystemversion,description,distinguishedname
$Computers | Select-Object dnshostname,operatingsystem,operatingsystemversion,description,distinguishedname

Get-DomainComputer -OperatingSystem 'Windows Server*' @LDAP |
    Select-Object dnshostname,operatingsystem
Get-DomainComputer -SPN 'MSSQLSvc/*' @LDAP |
    Select-Object dnshostname,serviceprincipalname
Get-DomainComputer -SearchBase '<OU-DN>' @LDAP | Select-Object dnshostname
```
- Pick `$Targets` from useful hosts. AD entries can be stale: confirm DNS + ports.

### Shares and SYSVOL
```powershell
Find-DomainShare -ComputerName $Targets -CheckShareAccess -Threads 1 @Net -Verbose
Get-NetShare -ComputerName '<FQDN>' @Net -Verbose

# Filenames in one share
Find-InterestingFile -Path '\\<FQDN>\<SHARE>' @Net `
    -Include '*pass*','*cred*','*.config','unattend*.xml'

# Shares on selected hosts
Find-InterestingDomainShareFile -ComputerName $Targets -Threads 1 @Net `
    -Include '*pass*','*.config'
```
- `-CheckShareAccess` tests listing only. File searches match names, not contents.

SYSVOL with the intended credential:
```powershell
New-PSDrive -Name PVSysvol -PSProvider FileSystem -Root "\\$DC\SYSVOL\$Domain" @Net | Out-Null
Get-ChildItem 'PVSysvol:\scripts' -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName
Get-ChildItem 'PVSysvol:\Policies' -Recurse -File -Filter '*.xml' |
    Select-String -Pattern 'cpassword' -List |
    Select-Object Path,LineNumber,Line
Remove-PSDrive -Name PVSysvol
```
- GPP: `gpp-decrypt '<CPASSWORD>'`. Keep credential source paths. Writable file needs a privileged load trigger → [spn-acl-shares](spn-acl-shares.md#shares-and-sysvol).

### Object ACLs
Build the account + group SID list, then inspect the exact target.

```powershell
$PrincipalSids = @((Get-DomainObject -Identity $Principal @LDAP -Properties objectsid).objectsid)
$PrincipalSids += @(Get-DomainGroup -MemberIdentity $Principal @LDAP | Select-Object -ExpandProperty objectsid)
$PrincipalSids += 'S-1-1-0','S-1-5-11'   # Everyone / Authenticated Users

$TargetAcl = Get-DomainObjectAcl -Identity '<TARGET-DN-OR-NAME>' -ResolveGUIDs @LDAP
$TargetAcl | Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object ObjectDN,ObjectSID,SecurityIdentifier,AceQualifier,ActiveDirectoryRights,
        ObjectAceType,InheritedObjectAceType,AceFlags
ConvertFrom-SID -ObjectSid '<SID>' @LDAP
```
- `ObjectSID` = target; `SecurityIdentifier` = ACE principal. Check allow/deny, inheritance, exact GUID; include BUILTIN groups and SID history.

| Right | Check next |
| --- | --- |
| `GenericAll` | User reset / group membership / computer attributes |
| `GenericWrite` / `WriteProperty` | Exact writable attribute |
| `WriteDacl` / `WriteOwner` | Required right; save original DACL/owner |
| `ExtendedRight` | Exact right, e.g. `User-Force-Change-Password` |
| `Self` / `WriteProperty` on `member` | Self-membership vs full group control |
| GPO write | AD object + SYSVOL + affected scope |

→ [object-rights](object-rights.md), [gpo-edges](gpo-edges.md).

Wider search:
```powershell
Find-InterestingDomainAcl -SearchBase '<OU-OR-DOMAIN-DN>' -ResolveGUIDs @LDAP |
    Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object ObjectDN,IdentityReferenceName,AceQualifier,ActiveDirectoryRights,ObjectAceType
```
- The helper skips low-RID SIDs: confirm hits with the exact target ACL.

## Lateral movement

### Local admin access
```powershell
Test-AdminAccess -ComputerName $Targets @Net -Verbose |
    Select-Object ComputerName,IsAdmin
Find-LocalAdminAccess -ComputerName $Targets -Threads 1 @Net -Verbose
Get-NetLocalGroupMember -ComputerName '<FQDN>' -GroupName 'Administrators' -Method API @Net |
    Select-Object ComputerName,GroupName,MemberName,SID,IsGroup,IsDomain
Test-NetConnection -ComputerName '<FQDN>' -Port 445
```
- `IsAdmin=True` = full Service Control Manager access. Expand returned domain groups. Localized Windows: use the real group name.

| Method | Port / access |
| --- | --- |
| SMB / service exec | 445 + share + service-control rights |
| WinRM | 5985/5986 + endpoint rights |
| WMI / DCOM | 135 + dynamic RPC + target rights |

→ [lateral-movement](lateral-movement.md).

### Sessions
```powershell
# Resource sessions; CName = connecting client
Get-NetSession -ComputerName '<FQDN>' @Net -Verbose |
    Select-Object ComputerName,UserName,CName,Time,IdleTime

# Workstation logons (may need extra rights)
Get-NetLoggedon -ComputerName '<FQDN>' @Net -Verbose |
    Select-Object ComputerName,UserName,LogonDomain,LogonServer

# Find one user on selected hosts
Find-DomainUserLocation -ComputerName $Targets -UserIdentity '<USER>' `
    -UserDomain $Domain -Server $DC -Threads 1 @Net -Verbose |
    Select-Object ComputerName,UserDomain,UserName,SessionFrom
```
- Empty / denied ≠ no users; your own query can create sessions. A session ≠ readable credentials; results include service/batch logons.
- `Find-DomainUserLocation`: the `LocalAdmin` field is unreliable: verify with `Test-AdminAccess`.

### GPO admin mappings
```powershell
Get-DomainOU @LDAP | Select-Object name,distinguishedname,gplink,gpoptions
Get-DomainGPO @LDAP | Select-Object displayname,name,gpcfilesyspath
Get-DomainGPO -ComputerIdentity '<FQDN>' @LDAP |
    Select-Object displayname,name,gpcfilesyspath

# Local-group settings in one GPO
Get-DomainGPOLocalGroup -Identity '<GPO-GUID>' -ResolveMembersToSIDs @LDAP |
    Select-Object GPODisplayName,GPOType,GroupName,GroupSID,GroupMembers,GroupMemberOf

# Account -> hosts with GPO Administrators membership
Get-DomainGPOUserLocalGroupMapping -Identity $Principal -LocalGroup 'Administrators' @LDAP |
    Select-Object ObjectName,GPODisplayName,ContainerName,ComputerName

# Host -> users/groups with GPO Administrators membership
Get-DomainGPOComputerLocalGroupMapping -ComputerIdentity '<FQDN>' `
    -LocalGroup 'Administrators' @LDAP |
    Select-Object ComputerName,ObjectName,IsGroup,GPODisplayName,GPOGuid
```
- Confirm live membership + link state + inheritance + security/WMI/item filtering. Link alone ≠ host control → [gpo-edges](gpo-edges.md).

## Post-exploitation

### New credentials
```powershell
$Principal = '<NEW-USER>'
$Cred = Get-Credential -UserName '<DOMAIN>\<NEW-USER>' -Message 'New credential'
$LDAP.Credential = $Cred
$Net.Credential = $Cred

Get-DomainGroup -MemberIdentity $Principal @LDAP | Select-Object samaccountname,objectsid
Test-AdminAccess -ComputerName $Targets @Net -Verbose
Find-DomainShare -ComputerName $Targets -CheckShareAccess -Threads 1 @Net -Verbose
```
- Rerun denied shares + promising ACLs/hosts; rebuild `$PrincipalSids` ([ACL checks](#object-acls)).
- Changed group membership → fresh logon. Local admin / SYSTEM → [windows/credential-access](../windows/credential-access.md).

### Delegation
```powershell
# Unconstrained (separate DCs from member hosts)
Get-DomainComputer -Unconstrained @LDAP | Select-Object dnshostname,useraccountcontrol

# Constrained: users and computers
Get-DomainObject -LDAPFilter '(msDS-AllowedToDelegateTo=*)' @LDAP |
    Select-Object samaccountname,useraccountcontrol,'msDS-AllowedToDelegateTo'

# Protocol-transition flag
Get-DomainUser -TrustedToAuth @LDAP |
    Select-Object samaccountname,'msDS-AllowedToDelegateTo'
Get-DomainComputer -TrustedToAuth @LDAP |
    Select-Object dnshostname,'msDS-AllowedToDelegateTo'

# Existing RBCD descriptor
Get-DomainComputer -LDAPFilter '(msDS-AllowedToActOnBehalfOfOtherIdentity=*)' @LDAP `
    -Properties dnshostname,'msDS-AllowedToActOnBehalfOfOtherIdentity' |
    Format-List
```
- Constrained: controlled account + allowed SPN. RBCD: decode the descriptor → allowed SIDs.
- New RBCD needs write on the target attribute + a controlled service principal → [delegation](delegation.md), [object-rights](object-rights.md).

### LAPS
```powershell
Get-DomainComputer -Identity '<FQDN>' @LDAP `
    -Properties dnshostname,'ms-Mcs-AdmPwd','msLAPS-Password','msLAPS-EncryptedPassword' |
    Select-Object dnshostname,'ms-Mcs-AdmPwd','msLAPS-Password',
        @{Name='EncryptedLapsPresent';Expression={$null -ne $_.'mslaps-encryptedpassword'}} |
    Format-List
```

| Attribute | Meaning |
| --- | --- |
| `ms-Mcs-AdmPwd` | Legacy LAPS password |
| `msLAPS-Password` | Windows LAPS JSON password |
| `msLAPS-EncryptedPassword` | Ciphertext: needs decryption rights + LAPS module (`Get-LapsADPassword`) |

- Empty = no read right / other storage / no value → [managed-credentials](managed-credentials.md).

### DCSync rights
Use `$PrincipalSids` from [ACL checks](#object-acls); query the domain root:

```powershell
$RootAcl = Get-DomainObjectAcl -Identity $DomainDN -ResolveGUIDs @LDAP
$RootAcl | Where-Object { $PrincipalSids -contains $_.SecurityIdentifier.Value } |
    Select-Object SecurityIdentifier,AceQualifier,ActiveDirectoryRights,ObjectAceType,AceFlags
```

| Required right | GUID |
| --- | --- |
| `DS-Replication-Get-Changes` | `1131f6aa-9c07-11d1-f79f-00c04fc2dcd2` |
| `DS-Replication-Get-Changes-All` | `1131f6ad-9c07-11d1-f79f-00c04fc2dcd2` |

- Both (or broader) rights must apply at the domain root. Check group SIDs, deny ACEs, filtered-set restrictions → [credential-access](credential-access.md#dc-database-or-replication).

## Save results
```powershell
$PVOut = Join-Path $PWD ('powerview-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $PVOut | Out-Null
"$Principal | $Domain | $DC | $(Get-Date -Format o)" |
    Set-Content -Path (Join-Path $PVOut 'context.txt')
$Users | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'users.xml')
$Computers | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'computers.xml')
$TargetAcl | Export-Clixml -Depth 5 -Path (Join-Path $PVOut 'target-acl.xml')
```
- Export before `Format-*`. CLIXML is not a restorable ACL backup: before object edits save original attributes + owner + DACL.

## Quick fixes
| Problem | Check |
| --- | --- |
| Missing command / bad parameter | `Get-Command`; `Get-Help <FUNCTION> -Full`; loaded version |
| LDAP fails | Credential, DC, domain DN, DNS, LDAP route; add `-Verbose` |
| LDAP works, host calls fail | RPC/SMB route, firewall, host rights, `@Net` credential |
| Finder skips an SMB host | Finders ping first: use `Get-NetShare`, `Get-NetSession` or `Test-AdminAccess` directly |
| UNC access denied | Use the intended logon or a credentialed PSDrive |
| Remoting differs | Token, second hop, [Kerberos](kerberos-troubleshooting.md) |
| ACL/GPO path fails | Groups, deny/inheritance, GUID, policy scope |
| Export loses values | Export raw objects; CLIXML or join arrays for CSV |

Path graph → [bloodhound](bloodhound.md). Native fallbacks → [active-directory-enum](active-directory-enum.md).

## Older aliases
| Older name | Current name |
| --- | --- |
| `Get-NetDomain` / `Get-NetDomainController` | `Get-Domain` / `Get-DomainController` |
| `Get-NetForest` | `Get-Forest` |
| `Get-NetUser` / `Get-NetGroup` / `Get-NetComputer` | `Get-DomainUser` / `Get-DomainGroup` / `Get-DomainComputer` |
| `Get-ObjectAcl` / `Convert-SidToName` | `Get-DomainObjectAcl` / `ConvertFrom-SID` |
| `Get-NetGPO` / `Get-NetGPOGroup` | `Get-DomainGPO` / `Get-DomainGPOLocalGroup` |
| `Invoke-ShareFinder` / `Invoke-FileFinder` | `Find-DomainShare` / `Find-InterestingDomainShareFile` |
| `Invoke-UserHunter` | `Find-DomainUserLocation` |

- `Get-NetSession` / `Get-NetLoggedon` keep their names. `Get-NetGPOGroup` reads local-group policy settings, not security-filtering groups.
- Use current parameters (`-Identity` for groups); check local help.
