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

## Fast first pass
```bash
nmap --min-rate 2000 -p- -Pn -oN nmap/fast.txt <IP>
rustscan -a <IP> --ulimit 5000 -- -sCV
```
- Then `-sCV` on the open ports (above). Drop `--min-rate` / rescan with `-T3` when ports flap or the VPN is lossy.
- Odd service: `nmap -sV --version-all -p<PORT> <IP>`.

## Targeted checks
```bash
nmap --script vuln -p$ports -Pn <IP>
nmap --script smb-vuln-ms17-010 -p445 -Pn <IP>
sudo nmap -sU -p 53,69,123,161,500,623 -sCV -Pn <IP>
```
- UDP list: DNS 53 · TFTP 69 · NTP 123 · SNMP 161 · IKE 500 · IPMI 623.
- `--script vuln` is slow and noisy: read the hits, confirm manually.

## Host discovery
```bash
nmap -sn <SUBNET>/24 -oN nmap/hosts.txt
fping -asgq <SUBNET>/24
```
- `-sn` on the local segment uses ARP; across a router add `-PE -PS445,3389,22` or scan `-Pn` on known IPs.

## Discovery without tools (foothold)
```bash
for i in $(seq 1 254); do (ping -c1 -W1 <SUBNET-PREFIX>.$i >/dev/null && echo <SUBNET-PREFIX>.$i up) & done; wait
for p in 22 80 445 3389; do (echo >/dev/tcp/<IP>/$p) 2>/dev/null && echo "$p open"; done
```
```powershell
1..254 | % { if (Test-Connection -Count 1 -Quiet <SUBNET-PREFIX>.$_) { "<SUBNET-PREFIX>.$_ up" } }
22,80,135,445,3389,5985 | % { if ((Test-NetConnection <IP> -Port $_ -WarningAction SilentlyContinue).TcpTestSucceeded) { "$_ open" } }
```
- `<SUBNET-PREFIX>` = first three octets (`10.10.10`). Windows may block ICMP: scan ports instead.

## Scanning through a pivot
| Pivot | Scan | Note |
| --- | --- | --- |
| Ligolo-ng route | `nmap --unprivileged -Pn -p- <IP>` (or `-PE`) | agent turns SYN into connect(): without the flag nmap reports false positives |
| proxychains (Chisel / SSH) | `proxychains nmap -sT -Pn -p<PORTS> <IP>` | no UDP / ICMP; `--top-ports 100`, very slow |
| static nmap on the pivot | `./nmap -sT -Pn -p- <IP>` | upload the binary, scan from there |

## Hostnames and virtual hosts
Use the discovered hostname for vhost/SNI; the bare IP may differ.

```bash
echo "<IP> <DOMAIN.TLD> <DC-FQDN> target" | sudo tee -a /etc/hosts
```
