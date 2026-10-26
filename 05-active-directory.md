# 05 · Active Directory

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Record domain, DC, credential; per path: account + right + target + service. Start: [AD enumeration](ad/active-directory-enum.md) · Windows shell: [PowerView](ad/powerview.md).

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| First domain picture | List users, groups, shares, hosts, policy | [LDAP and sessions](ad/ldap-and-sessions.md) · [BloodHound](ad/bloodhound.md) |
| Roastable account | No pre-auth or user SPN; check lockout | [Authentication](ad/authentication.md) |
| Useful object right | Principal, ACL right, target | [Object rights](ad/object-rights.md) · [PowerView ACL checks](ad/powerview.md#object-acls) |
| Share or SYSVOL lead | Readable creds; writable loaded content | [Shares and SYSVOL](ad/spn-acl-shares.md) |
| MSSQL access | SQL vs Windows login, role, impersonation, links | [MSSQL](enum/mssql.md) |
| Session or admin edge | Local admin where a session exists? | [Sessions](ad/ldap-and-sessions.md#hosts-and-sessions) · [Lateral movement](ad/lateral-movement.md) |
| GPO edge | GPO right, linked scope, affected hosts | [GPOs](ad/gpo-edges.md) |
| AD CS | Enrollment service; enrollable template? | [AD CS](ad/adcs.md) |
| Local admin or SYSTEM | Local secrets via a confirmed right | [Windows credential access](windows/credential-access.md) |
| DC database or replication right | Read NTDS or replicate secrets? | [AD credential access](ad/credential-access.md) |
| Ticket material | Match key/ticket to account, SPN, domain | [Tickets](ad/tickets.md) |
| Delegation | Direction, controlled principal, allowed SPN | [Delegation](ad/delegation.md) |
| LAPS or gMSA | Read right ≠ host/service access | [Managed credentials](ad/managed-credentials.md) |
| Privileged group | DC/host scope, token, exact operation | [AD/DC groups](ad/privileged-groups.md) |
| Live NTLM authentication | Source policy, destination signing, rights | [NTLM relay](ad/ntlm-relay.md) |
| Kerberos fails | FQDN, DNS, clock, SPN, ticket cache | [Kerberos checks](ad/kerberos-troubleshooting.md) |
| Login but no execution | Local admin; matching remote service open? | [Lateral movement](ad/lateral-movement.md) |
| Advanced object path | Prerequisite rights, DC support | [Advanced object paths](ad/object-rights.md#sealed-ldap-object-restore--newer-primitives) |

After new credentials, re-enumerate with that account. Confirm BloodHound rights on the target.
