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
