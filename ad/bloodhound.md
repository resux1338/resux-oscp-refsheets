# BloodHound collection and path checks

Collect for the path question; mark only principals you control as owned.

```cmd
SharpHound.exe --Domain <DOMAIN.TLD> --CollectionMethods Default --OutputDirectory C:\Users\<USER>\Desktop
```
```bash
bloodhound-ce-python -u <USER> -p '<PW>' -d <DOMAIN.TLD> -ns <DC-IP> -c Default --zip
nxc ldap <DC-IP> -u <USER> -p '<PW>' --bloodhound -c all --dns-server <DC-IP>
```
- Match collector to BloodHound CE vs Legacy: `bloodhound-ce-python` / SharpHound CE for CE, `bloodhound-python` for ≤ 4.3. nxc `--bloodhound` defaults to CE.
- Collection errors can leave missing edges. Re-collect after gaining a principal.

## Queries to adapt
Replace `<DOMAIN.TLD>` with the suffix used in object names (uppercase).

```cypher
MATCH p=(n:User)-[:MemberOf*1..]->(m:Group)
WHERE m.name = "DOMAIN ADMINS@<DOMAIN.TLD>"
RETURN p
```
```cypher
MATCH p=(m:User)-[:MemberOf*1..]->(n:Group)
WHERE n.name = "DOMAIN ADMINS@<DOMAIN.TLD>"
MATCH q=(m)<-[:HasSession]-(o:Computer)
RETURN p, q
```
- `GPLink` edges → [gpo-edges](gpo-edges.md).

## Edge → abuse
| Edge | Abuse | Detail |
| --- | --- | --- |
| `ForceChangePassword` | Reset the password | [object-rights](object-rights.md#password-reset-and-group-membership) |
| `AddMember` | Add yourself to the group | [object-rights](object-rights.md#password-reset-and-group-membership) |
| `GenericAll` / `GenericWrite` (user) | SPN write (targeted Kerberoast) or shadow credentials | [object-rights](object-rights.md#targeted-kerberoast-spn-write) |
| `GenericAll` / `GenericWrite` (group) | Add yourself as a member | [object-rights](object-rights.md#password-reset-and-group-membership) |
| `GenericAll` / `GenericWrite` (computer) | Write RBCD on the computer | [delegation](delegation.md#rbcd) |
| `WriteDACL` | Grant yourself a right via `dacledit` | [object-rights](object-rights.md#owner-and-dacl) |
| `WriteOwner` | Take ownership via `owneredit`, then `WriteDACL` | [object-rights](object-rights.md#owner-and-dacl) |
| `AddKeyCredentialLink` | Shadow credentials | [object-rights](object-rights.md#shadow-credentials) |
| `ReadLAPSPassword` | Read `ms-Mcs-AdmPwd` / `msLAPS-Password` | [managed-credentials](managed-credentials.md) |
| `ReadGMSAPassword` | Read `msDS-ManagedPassword` | [managed-credentials](managed-credentials.md) |
| `AllowedToDelegate` | Constrained delegation (S4U2Self/S4U2Proxy) | [delegation](delegation.md#constrained-delegation) |
| `AllowedToAct` | You already control the resource side of RBCD | [delegation](delegation.md#rbcd) |
| `CanPSRemote` | WinRM shell | [remote-access](../enum/remote-access.md#winrm) |
| `CanRDP` | RDP session | [remote-access](../enum/remote-access.md#rdp) |
| `AdminTo` | PsExec/WMI/WinRM execution | [lateral-movement](lateral-movement.md) |
| `HasSession` | Dump LSASS on that host for the session owner's creds | [credential-access](../windows/credential-access.md#lsass) |
| `DCSync` | `secretsdump` against the DC | [credential-access](credential-access.md#dcsync-inspect-rights-and-select-the-account) |
| `GPLink` | GPO edit/abuse | [gpo-edges](gpo-edges.md) |

## Built-in queries worth clicking first
Right-click a controlled principal → "Mark User as Owned" (or Computer/Group) before running these.
- **Shortest Paths → Shortest paths from Owned objects**: everywhere your current foothold can reach.
- **Shortest Paths → Shortest paths to Domain Admins**: the reverse view, from any principal.
- **Dangerous Privileges → Principals with DCSync privileges**, **Computers where Domain Users can read LAPS passwords**, **Workstations/Servers where Domain Users can RDP**.
- **Kerberos Interaction → All Kerberoastable users**, **AS-REP Roastable users (DontReqPreAuth)**, **Shortest paths to Domain Admins from Kerberoastable users**.
- **Active Directory Certificate Services → \*** if ADCS is in scope: cross-link [adcs](adcs.md).

## More Cypher
```cypher
MATCH (u:User)
WHERE u.hasspn = true AND u.enabled = true
  AND NOT u.objectid ENDS WITH '-502'
  AND NOT COALESCE(u.gmsa, false) = true AND NOT COALESCE(u.msa, false) = true
RETURN u
```
```cypher
MATCH (u:User)
WHERE u.dontreqpreauth = true AND u.enabled = true
RETURN u
```
```cypher
MATCH (c:Computer)
WHERE c.unconstraineddelegation = true AND c.isdc = false
RETURN c
```
```cypher
MATCH p=(u:User)-[:CanRDP|CanPSRemote]->(c:Computer)
RETURN p
```
- Kerberoastable-with-paths is the built-in "Shortest paths to Domain Admins from Kerberoastable users" above — same filter, plus the path.
