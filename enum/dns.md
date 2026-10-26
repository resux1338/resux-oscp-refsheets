# DNS records and zone transfers

## Record queries
Keep names for vhosts, Kerberos, mail, TLS.

```bash
dig @<IP> <DOMAIN.TLD> SOA
dig @<IP> <DOMAIN.TLD> NS
dig @<IP> <DOMAIN.TLD> MX
dig @<IP> <DOMAIN.TLD> TXT
dig @<IP> _ldap._tcp.dc._msdcs.<DOMAIN.TLD> SRV
dig @<IP> -x <IP>
nslookup -q=TXT <DOMAIN.TLD> <IP>
```

## Zone transfer
If refused, query record types directly.

```bash
dig @<IP> <DOMAIN.TLD> AXFR
dnsrecon -d <DOMAIN.TLD> -n <IP> -t axfr
```

## Subdomain brute force
```bash
gobuster dns -d <DOMAIN.TLD> -w <wordlist> --resolver <IP>
dnsrecon -d <DOMAIN.TLD> -n <IP> -t brt -D <wordlist>
dnsenum --dnsserver <IP> -f <wordlist> <DOMAIN.TLD>
```
- `gobuster dns --resolver`: custom resolver to query (point it at the target so internal-only names resolve). No short flag for this one.
- `dnsenum` (classic Perl): also tries zone transfer and Google scraping unless told not to; `--noreverse` skips the PTR sweep it does by default.

## Reverse sweep
```bash
dnsrecon -r <SUBNET>/24 -n <DC-IP>
```
- `-r` alone implies the reverse-lookup scan type; no `-t` needed.

## AD-integrated DNS with creds
Dumps every record in the zone via LDAP, similar to a zone transfer but needs a domain account (no zone-transfer misconfig required).
```bash
adidnsdump -u '<DOMAIN>\<USER>' -p '<PW>' <DC-IP>
adidnsdump -u '<DOMAIN>\<USER>' -p '<PW>' -r <DC-IP>
```
- `-r` / `--resolve`: also resolves records hidden from normal zone enumeration. Output: `records.csv` in the current directory.
- Pivoting through proxychains → add `--dns-tcp`.
