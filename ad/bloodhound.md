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
