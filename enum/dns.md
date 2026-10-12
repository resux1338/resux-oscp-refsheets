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
