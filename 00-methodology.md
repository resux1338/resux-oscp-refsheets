# 00 · Methodology

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

`enumerate → pick a lead → prove its conditions → gain access/info → enumerate again`

## Start
- [ ] Notes: IP, hostname, domain, route, current credential.
- [ ] Full TCP + selected UDP → service/version scans on open ports. Save output.
- [ ] Names from DNS, redirects, certificates → test web by hostname. [Recon](01-recon.md) · [UDP](enum/network-scanning.md)

## New clue → re-enumerate
- Name → DNS, vhosts, certificates, named web response. [DNS](enum/dns.md)
- Username → scope, Kerberos, SMB/LDAP, password policy. [AD](05-active-directory.md)
- Credential → matching services/hosts, new rights. [Passwords](07-password-attacks.md)
- Web app/login → JS, functions, parameters, roles, logged-in paths. [Web](web/web-enumeration.md)
- Shell/new privilege → identity, local ports, configs, secrets, routes. [Linux](03-linux-privesc.md) · [Windows](04-windows-privesc.md)
- Interface/subnet → hosts and services through the pivot. [Pivoting](06-pivoting.md)
- AD principal/right → groups, ACLs, sessions, paths. [BloodHound](ad/bloodhound.md)

## Service / web pass
- [ ] Service: version → anonymous/guest → default or found credential → data. [Service index](enum/service-triage.md)
- [ ] Public exploit: exact version, config, rights, trigger; read the PoC. [Exploit checks](foothold/public-exploits.md)
- [ ] Web: browse, source/JS, request/response, paths, vhosts, framework/CMS/plugins. [Web enum](web/web-enumeration.md)
- [ ] Map roles, functions, parameters. Change one input; compare baseline. New role? Browse again. [Web paths](02-foothold.md)

## Every credential is an enumeration event
- [ ] Log `account | material type | local/domain | source | services | rights | reuse tested`.
- [ ] Test only where material, account scope and service match. Login success ≠ execution.
- [ ] Check lockout policy before online guesses. NetNTLMv2 → offline crack, not Pass the Hash. [Passwords](07-password-attacks.md) · [Remote login](enum/remote-access.md)

## Shell reset / privesc
- [ ] `id` / `whoami`; hostname, groups/token, interfaces/routes, loopback listeners.
- [ ] Users, processes/services, configs, history, creds, writable paths, reachable hosts. [Linux](linux/enumeration.md) · [Windows](windows/enumeration.md)
- [ ] Domain-joined? Run [AD baseline](ad/active-directory-enum.md).
- [ ] Linux: `user → controlled component → root-run process → trigger`. Windows: `account → right → target → privileged trigger`.
- [ ] Confirm new identity; enumerate again. Failed? Check token/ACL, service state, trigger.

## AD / pivot reset
- [ ] AD: domain/DC/DNS → users, groups, computers, policy, shares, SPNs, sessions, ACLs, local admin, AD CS. [AD](05-active-directory.md)
- [ ] Path: `principal → right/credential → target → reachable service → next principal`. Repeat with each new principal.
- [ ] Kerberos fails? FQDN, DNS, clock, SPN, cache. [Kerberos checks](ad/kerberos-troubleshooting.md)
- [ ] Pivot: record subnet, pivot, route. Repeat [Recon](01-recon.md) through the [tunnel](06-pivoting.md).

## Stuck?
- [ ] Reread scans; unusual ports, slower retry, selected UDP. Hostname instead of IP?
- [ ] Web source/JS/API, backups, logged-in vs anonymous functions?
- [ ] Collected creds: right type, scope, target, alternate service?
- [ ] Loopback ports, process args, configs, tasks, writable files?
- [ ] PoC/shell: prerequisites, listener/route?
- [ ] BloodHound: collection errors, owned principals, direct ACLs, sessions?
- [ ] New interface/route? What changed since last enum?

## Notes
- Proof and report rules: [Exam documentation](documentation/exam-checklist.md). Screenshot hotkey and logging: [setup](documentation/screenshots-and-logging.md).
- Keep hosts/ports, versions, URLs, creds with scope/source, decisive commands, failed checks, shells, routes, `principal → right → target`.
