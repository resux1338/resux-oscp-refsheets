<div align="center">

# resux-oscp-refsheets

Command reference for OSCP+ and CPTS.

![OSCP+](https://img.shields.io/badge/OSCP%2B-exam_prep-1f2328?style=flat-square)
![CPTS](https://img.shields.io/badge/CPTS-practice-1f2328?style=flat-square)
![Kali](https://img.shields.io/badge/Kali-rolling-367bf0?style=flat-square&logo=kalilinux&logoColor=white)

[00 Methodology](00-methodology.md) ·
[01 Recon](01-recon.md) ·
[02 Foothold](02-foothold.md) ·
[03 Linux](03-linux-privesc.md) ·
[04 Windows](04-windows-privesc.md) ·
[05 AD](05-active-directory.md) ·
[06 Pivoting](06-pivoting.md) ·
[07 Passwords](07-password-attacks.md)

</div>

```text
enumerate → lead → prove preconditions → access → re-enumerate
```

## Entry points

- `linux shell` → [Linux first pass](linux/enumeration.md)
- `windows shell` → [Windows first pass](windows/enumeration.md)
- `domain creds` → [AD baseline](ad/active-directory-enum.md)
- `no progress` → [Methodology and stuck checklist](00-methodology.md)

## [01 · Recon](01-recon.md)

- `scan` [Nmap TCP/UDP, vhosts](enum/network-scanning.md) · [Port → service map](enum/service-triage.md)
- `services` [SMB / RPC](enum/smb.md) · [FTP](enum/ftp.md) · [NFS](enum/nfs.md) · [DNS / AXFR](enum/dns.md) · [SNMP](enum/snmp.md) · [SMTP / IMAP / POP3](enum/mail.md) · [SSH, Telnet, Finger, rsync, TFTP](enum/other-services.md)
- `db` [MySQL / PostgreSQL / Redis](enum/databases-and-redis.md) · [MSSQL: impersonation, links, xp_cmdshell](enum/mssql.md)
- `auth` [RDP / WinRM / SSH](enum/remote-access.md)

## [02 · Foothold](02-foothold.md)

- `web` [Enumeration](web/web-enumeration.md) · [Fingerprinting](web/fingerprinting.md) · [Path normalization, known apps](web/application-paths.md)
- `inject` [SQLi: in-band, blind, MSSQL](web/manual-sqli.md) · [NoSQL](web/nosql.md) · [SSTI](web/ssti.md) · [Command injection, upload, traversal](web/files-and-commands.md)
- `fetch` [LFI → RCE](web/lfi.md) · [RFI](web/rfi.md) · [SSRF](web/ssrf.md) · [XXE](web/xxe.md)
- `authz` [IDOR, mass assignment, OAuth/SAML, JWT](web/authentication.md) · [GraphQL](web/graphql.md) · [ViewState deserialization](web/insecure-deserialization.md) · [XSS](web/xss.md)
- `exploit` [Public PoCs: search, adapt, compile](foothold/public-exploits.md) · [Client-side: SMTP, VBA macro, WebDAV .lnk](foothold/client-side-phishing.md)
- `post` [Reverse shells, TTY, ConPtyShell, msfvenom](foothold/shells.md) · [File transfer](foothold/file-transfer.md)

## [03 · Linux privesc](03-linux-privesc.md)

- `enum` [First pass, linPEAS, pspy](linux/enumeration.md)
- `sudo` [sudo -l, GTFOBins, module hijack](linux/sudo.md) · [SUID / SGID / capabilities](linux/suid-and-capabilities.md)
- `root-run` [Cron, timers, services](linux/root-run.md) · [Symlink and archive writes](linux/file-write.md)
- `groups` [docker / lxd, NFS no_root_squash](linux/groups-and-nfs.md)
- `misc` [rbash escapes](linux/restricted-shells.md) · [Kernel exploits](linux/kernel-checks.md)

## [04 · Windows privesc](04-windows-privesc.md)

- `enum` [First pass, winPEAS, PowerUp](windows/enumeration.md)
- `tokens` [Se* privileges, local groups](windows/token-groups.md) · [Potatoes: Sigma, God, PrintSpoofer, EFS, Juicy, Rogue](windows/potato.md)
- `services` [AlwaysInstallElevated](windows/services.md) · [Binary hijack](windows/service-binary-hijacking.md) · [Weak service ACL / binPath](windows/service-permissions.md) · [Unquoted paths](windows/unquoted-service-paths.md) · [DLL hijack](windows/dll-hijacking.md)
- `tasks` [Scheduled tasks, autoruns](windows/scheduled-tasks-and-autoruns.md)
- `creds` [Hunting, runas, DPAPI](windows/credentials.md) · [SAM / LSA / LSASS, Mimikatz](windows/credential-access.md)
- `ntlm` [NT vs NetNTLMv2](windows/ntlm.md) · [Coercion files, ntlm_theft](windows/ntlm-capture.md)

## [05 · Active Directory](05-active-directory.md)

- `enum` [Baseline](ad/active-directory-enum.md) · [PowerView](ad/powerview.md) · [LDAP, sessions](ad/ldap-and-sessions.md) · [BloodHound queries](ad/bloodhound.md)
- `kerberos` [AS-REP / Kerberoast](ad/authentication.md) · [Tickets: PtT, Silver, Golden, ExtraSID](ad/tickets.md) · [Delegation: KCD, RBCD, unconstrained](ad/delegation.md) · [KRB error fixes](ad/kerberos-troubleshooting.md)
- `acl` [GenericAll/Write, WriteDACL/Owner, targeted roast](ad/object-rights.md) · [SPNs, ACLs, SYSVOL](ad/spn-acl-shares.md) · [GPO edges](ad/gpo-edges.md)
- `groups` [DnsAdmins, Server/Backup/Account Operators](ad/privileged-groups.md)
- `adcs` [ESC1, ESC4, ESC8, PKINIT](ad/adcs.md)
- `secrets` [LAPS / gMSA](ad/managed-credentials.md) · [DCSync / NTDS.dit](ad/credential-access.md)
- `relay` [ntlmrelayx: SMB, LDAP, ESC8](ad/ntlm-relay.md)
- `lateral` [PtH, PtT, PsExec, WMI, WinRM](ad/lateral-movement.md)

## [06 · Pivoting](06-pivoting.md)

- `ssh` [-L / -R / -D, socat, sshuttle](pivoting/ssh-socat.md)
- `tunnel` [Chisel SOCKS, Ligolo-ng](pivoting/chisel-ligolo.md)
- `windows` [Port relays, proxychains checks](pivoting/windows-and-proxy.md)

## [07 · Passwords](07-password-attacks.md)

- `offline` [Hash ID, NT vs NetNTLMv2](passwords/cracking.md#identify-the-hash) · [hashcat, john, *2john, shadow, rules](passwords/cracking.md)
- `online` [Spraying, brute force](passwords/online-logins.md)

---

[`scripts/`](scripts/README.md): executable-reference finder (PowerShell), VBA payload chunker. [`REFERENCES.md`](REFERENCES.md): external links by topic.

```text
<IP> target   <KALI> tun0   <SUBNET>   <PORT>
<DOMAIN> NetBIOS   <DOMAIN.TLD>   <DC-IP>   <DC-FQDN>   <FQDN> non-DC host
<USER>   <PW>   <NT>   <HOSTNAME>   <COMPUTER>   <TARGET>   <SERVICE>   <SVC>   <GMSA>   <GROUP>   <SHARE>
<IMPERSONATE>   <LOCAL-USER>   <AES256-KEY>   <PFX>   <CA-FQDN>   <DLL-PATH>   <CONSOLE-PORT>   <SOURCE-IP>
```

> [!IMPORTANT]
> Read the current [OffSec exam guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide) before the exam.
