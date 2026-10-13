# 03 · Linux Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Baseline first; per lead confirm privilege, writable target, trigger. Start: [Linux enumeration](linux/enumeration.md).

```bash
id; sudo -l; uname -r; cat /etc/os-release
```

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Sudo rule | Binary, arguments, env, run-as user | [Sudo rules](linux/sudo.md) |
| SUID or capability | Owner, context, retained identity | [SUID and capabilities](linux/suid-and-capabilities.md) |
| Root-run script or service | Writable file, command, path, env? Trigger? | [Root-run files](linux/root-run.md) |
| Cron or timer | Run-as user, schedule, writable part | [Root-run files](linux/root-run.md#find-the-path) |
| Privileged file write | Root process follows your path/archive? | [File-write paths](linux/file-write.md) |
| Docker or LXD | Group membership; rootful daemon socket | [Groups and containers](linux/groups-and-nfs.md) |
| NFS export | Client access, write, root squashing | [NFS](linux/groups-and-nfs.md#nfs) |
| Saved credential | Configs, history, backups, local services | [Credential checks](linux/enumeration.md#users-homes-credentials) |
| Restricted shell | Allowed interpreter that spawns a shell? | [Restricted shells](linux/restricted-shells.md) |
| Sudo version bug or env | `sudo -V`, `env_keep`, `sudoedit` rule | [Sudo version bugs](linux/sudo.md#sudo-version-bugs) · [LD_PRELOAD](linux/sudo.md#ld_preload-kept-by-sudo) |
| Wildcard or relative command in a root job | Bare `*` in a writable dir; job's PATH | [Wildcards and PATH](linux/root-run.md#wildcard-injection) |
| Custom SUID binary | Relative command, missing/writable library | [Custom SUID](linux/suid-and-capabilities.md#custom-suid-path-and-missing-library) |
| SSH key, agent or login file | Readable key, agent socket, writable `authorized_keys` | [SSH and keys](linux/ssh-and-keys.md) |
| Process secrets, writable hooks, doas, tmux/screen | Readable cmdline/env, writable MOTD/profile.d | [Less common vectors](linux/misc-vectors.md) |
| Kernel or package issue | Exact build, architecture, patch state | [Kernel checks](linux/kernel-checks.md) · [CVE patterns](linux/kernel-checks.md#known-cve-patterns) |

Failed path: check current user, ACL, trigger ran.
