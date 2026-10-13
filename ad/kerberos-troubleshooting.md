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
| `KRB_AP_ERR_SKEW` | Local vs DC time (limit 5 min): [sync the clock](#sync-the-clock) before retrying |
| `KDC_ERR_WRONG_REALM` | Exact domain FQDN / realm |
| No KDC reached | DNS, `/etc/hosts`, route, DC address |
| Ticket exists, service fails | SPN, target FQDN, ticket account, clock |
| LDAP bind needs stronger auth | Signing / SASL requirements and tool support; LDAPS has separate TLS / channel-binding checks |
| `KDC_ERR_ETYPE_NOSUPP` | Account's supported encryption, key type available (NT = RC4, AES keys are separate), DC defaults |
| `KDC_ERR_BADOPTION` during S4U | [Delegation](delegation.md): direction, allowed SPN, evidence ticket, target-user restrictions |
| `KDC_ERR_PADATA_TYPE_NOSUPP` with a certificate | DC PKINIT support / certificate config; Schannel instead → [adcs](adcs.md#pkinit-and-schannel-failures) |
| Certificate SID / identity mismatch | Requested vs issued identity, strong mapping, template / CA config, exact target object |

## Sync the clock
Read the DC's time, set Kali to it, retry. Turn off automatic sync first or the clock jumps back.

```bash
date -u
nmap -Pn -p445 --script smb2-time <DC-IP>
sudo timedatectl set-ntp false
sudo ntpdate <DC-IP>
```
- `smb2-time` reads the DC's clock over SMB when UDP/123 is blocked. Then set it by hand: `sudo date -u -s '<YYYY-MM-DD HH:MM:SS>'` (use the UTC value).
- Other setters: `sudo rdate -n -s <DC-IP>`, `sudo net time set -S <DC-IP>`.
- Per-command skew without changing the system clock (offset or absolute time):
```bash
faketime -f '+7h' impacket-GetUserSPNs <DOMAIN.TLD>/<USER>
faketime '<YYYY-MM-DD HH:MM:SS>' impacket-getTGT <DOMAIN.TLD>/<USER>
```
- VM guest time sync (VMware tools / VirtualBox additions) can undo the change; disable it for the VM.
- Restore afterwards: `sudo timedatectl set-ntp true`.
- Still `SKEW` after syncing: wrong DC (several DCs, different clocks), time zone confusion (use UTC), or the ticket cache was created earlier: `kdestroy` / delete the `.ccache` and request again.

## Minimal `krb5.conf` for `kinit`, `evil-winrm -r`, `ssh` with GSSAPI
Realm names are upper case, DNS names lower case.

```text
[libdefaults]
    default_realm = <DOMAIN.TLD>
    dns_lookup_kdc = false
    dns_lookup_realm = false

[realms]
    <DOMAIN.TLD> = {
        kdc = <DC-FQDN>
        admin_server = <DC-FQDN>
    }

[domain_realm]
    .<domain.tld> = <DOMAIN.TLD>
    <domain.tld> = <DOMAIN.TLD>
```
```bash
echo '<DC-IP> <DC-FQDN>' | sudo tee -a /etc/hosts
kinit <USER>@<DOMAIN.TLD>
klist
evil-winrm -i <FQDN> -r <DOMAIN.TLD>
```
- `kinit` stores the TGT in `KRB5CCNAME` (default `/tmp/krb5cc_<UID>`). Use the FQDN, not the IP, for any Kerberos-authenticated service.
