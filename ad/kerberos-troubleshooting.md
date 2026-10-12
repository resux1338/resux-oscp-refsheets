# Kerberos troubleshooting

Use the domain FQDN and service FQDN; keep each cache tied to its account.

```bash
getent hosts <DC-FQDN>
date -u
klist
echo "$KRB5CCNAME"
```
- Get a matching TGT, set `KRB5CCNAME`, then use the tool's cache flags (usually `-k -no-pass`).

| Error / symptom | Check |
| --- | --- |
| `KRB_AP_ERR_SKEW` | Local vs DC time: sync before retrying |
| `KDC_ERR_WRONG_REALM` | Exact domain FQDN / realm |
| No KDC reached | DNS, `/etc/hosts`, route, DC address |
| Ticket exists, service fails | SPN, target FQDN, ticket account, clock |
| LDAP bind needs stronger auth | Signing / SASL requirements and tool support; LDAPS has separate TLS / channel-binding checks |
| `KDC_ERR_ETYPE_NOSUPP` | Account's supported encryption, key type available (NT = RC4, AES keys are separate), DC defaults |
| `KDC_ERR_BADOPTION` during S4U | [Delegation](delegation.md): direction, allowed SPN, evidence ticket, target-user restrictions |
| `KDC_ERR_PADATA_TYPE_NOSUPP` with a certificate | DC PKINIT support / certificate config; Schannel instead → [adcs](adcs.md#pkinit-and-schannel-failures) |
| Certificate SID / identity mismatch | Requested vs issued identity, strong mapping, template / CA config, exact target object |
