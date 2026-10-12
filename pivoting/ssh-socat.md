# SSH and Socat forwards

## Port forwards
```bash
# Local: Kali opens a port to a service reachable from the SSH server
ssh -N -L 8000:127.0.0.1:8000 <USER>@<IP>

# Remote: run on the foothold; Kali listens on 127.0.0.1:2345 → internal service
ssh -N -R 127.0.0.1:2345:<IP>:5432 <USER>@<KALI>
```
```bash
# Single TCP relay on a foothold
socat -ddd TCP-LISTEN:2345,fork TCP:<IP>:5432
```
- `-L` listens on the SSH-client host.
- `ss -lntp`: bind `0.0.0.0` only when others need to reach it.

## SOCKS / subnet
```bash
ssh -N -D 1080 <USER>@<IP>
proxychains nmap -sT -Pn -p 139,445,3389 <IP>
sshuttle -r <USER>@<IP> <SUBNET>/24
```
- Set `socks5 127.0.0.1 1080` in `/etc/proxychains4.conf`.
- Through SOCKS: Nmap `-sT -Pn` only (no SYN, UDP or ping).
- sshuttle: avoid route overlap with the local network.
