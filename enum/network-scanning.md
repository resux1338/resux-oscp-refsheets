# Network scanning

## TCP and UDP scans
Full TCP discovery, then deep scan on open ports.

```bash
mkdir -p nmap
nmap -p- -T3 -Pn -oN nmap/allports.txt <IP>
ports=$(awk '$2=="open" {split($1,a,"/"); print a[1]}' nmap/allports.txt | paste -sd,)
nmap -p$ports -sCV -Pn -oN nmap/deep.txt <IP>
sudo nmap -sU --top-ports 100 -oN nmap/udp.txt <IP>
```
- `-sCV` = default scripts + version; `-Pn` skips host discovery; `-A` includes `-sC -sV`.
- Lossy VPN / empty result → rescan slower.
- Note OS hint, hostname, domain name → add to `/etc/hosts`.
- AutoRecon / nmapAutomator: read output yourself.

## Hostnames and virtual hosts
Use the discovered hostname for vhost/SNI; the bare IP may differ.

```bash
echo "<IP> <DOMAIN.TLD> <DC-FQDN> target" | sudo tee -a /etc/hosts
```
