# 06 · Pivoting & Tunneling

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Foothold → target reachability first; then port forward, SOCKS or subnet route.

| Need | Quick fit check | Details |
| --- | --- | --- |
| One internal TCP service | Foothold reaches host:port? Which end listens? | [SSH and Socat](pivoting/ssh-socat.md) |
| Several TCP services | SSH client or Chisel on foothold? | [SSH and Socat](pivoting/ssh-socat.md) · [Chisel](pivoting/chisel-ligolo.md) · [Cross-compile Chisel](pivoting/chisel-ligolo.md#cross-compile-chisel) |
| Whole subnet | Ligolo agent; no conflicting route | [Ligolo](pivoting/chisel-ligolo.md#ligolo-ng) |
| Windows-only foothold | `Test-NetConnection`; port relay or tunnel | [Windows pivots](pivoting/windows-and-proxy.md) |
| Callback through a pivot | Listener location; return port forwarded? | [Ligolo listener](pivoting/chisel-ligolo.md) · [SSH forwards](pivoting/ssh-socat.md) |
| Scan over SOCKS is empty | Proxy address, DNS; `nmap -sT -Pn` | [Proxy checks](pivoting/windows-and-proxy.md) |

New host reachable → back to [Recon](01-recon.md) through the route.
