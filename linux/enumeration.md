# Linux enumeration

## First pass
```bash
id
groups
sudo -l
hostname
uname -a
cat /etc/os-release
env
printf '%s\n' "$PATH"
```
- Every sudo rule: note exact command, arguments, run-as user, environment → [sudo](sudo.md), [root-run](root-run.md).

## Users, homes, credentials
```bash
getent passwd
getent group
w
last -n 20
ls -la /home /home/* /opt /srv /var/www /var/backups 2>/dev/null
find /var/backups /opt /srv /var/www -maxdepth 3 -type f 2>/dev/null
```
```bash
find "$HOME" /home /opt /srv /var/www /var/backups -maxdepth 4 -type f \
  \( -name '.*history' -o -name '.viminfo' -o -name 'id_rsa' -o -name '*.conf' \
     -o -name '*.ini' -o -name '*.yml' -o -name '*.yaml' -o -name '.env' -o -name '*.bak' \) \
  -readable 2>/dev/null

grep -RniE 'pass(word)?|secret|token|api.?key|connection.?string' \
  "$HOME" /opt /srv /var/www 2>/dev/null

ls -la /var/mail /var/spool/mail 2>/dev/null
```
- Try found creds only against plausible accounts/services.

## Processes, cron, timers, services
```bash
ps -eo user,pid,ppid,cmd --forest
crontab -l 2>/dev/null
cat /etc/crontab 2>/dev/null
ls -la /etc/cron.* /var/spool/cron /var/spool/cron/crontabs 2>/dev/null
systemctl list-timers --all 2>/dev/null
systemctl list-units --type=service --state=running 2>/dev/null
```
Short-lived root jobs not visible statically:
```bash
./pspy64
```
- Per lead: privileged caller, every script/binary it runs, which is writable, how often it fires.

## Network, mounts, containers
```bash
ip -brief address
ip route
cat /etc/resolv.conf
ss -lntup
findmnt
cat /etc/fstab
mount
```
```bash
ls -l /var/run/docker.sock /run/containerd/containerd.sock 2>/dev/null
systemd-detect-virt 2>/dev/null
cat /proc/1/cgroup 2>/dev/null
```
- Loopback-only listener → [forward it](../06-pivoting.md). Docker/LXD → [groups-and-nfs](groups-and-nfs.md).

## SUID, SGID, capabilities
```bash
find / -xdev -perm -4000 -type f -exec ls -la {} \; 2>/dev/null
find / -xdev -perm -2000 -type f -exec ls -la {} \; 2>/dev/null
getcap -r / 2>/dev/null
```
- `-xdev` skips other mounts: check those separately. → [suid-and-capabilities](suid-and-capabilities.md).

## Writable privileged paths
```bash
find /etc/cron.d /etc/cron.daily /etc/systemd/system /usr/local/bin /opt /srv \
  -xdev -writable -ls 2>/dev/null

find /opt /srv /var/www -xdev -type f -writable -ls 2>/dev/null
```
- Only useful if a more-privileged process runs/reads it and you can trigger it → [root-run](root-run.md), [file-write](file-write.md).

## Automated enumeration
```bash
./linpeas.sh | tee /tmp/linpeas.txt
./lse.sh -l 1
./pspy64
```
- Enumeration only; verify highlighted findings by hand.

## Where is the flag?
```bash
find /home /root -type f \( -name local.txt -o -name proof.txt \) -print 2>/dev/null
find / -type f \( -name local.txt -o -name proof.txt \) -print 2>/dev/null
cat '<FLAG-PATH>'
```
- `local.txt` = user context, `proof.txt` = root. Screenshot with hostname + full path.

## Triage
| Signal | Confirm | Notes |
| --- | --- | --- |
| Sudo rule | Binary, arguments, env, run-as user | [sudo](sudo.md) |
| Odd SUID/SGID/capability | Owner, mode/cap, mount flags | [suid-and-capabilities](suid-and-capabilities.md) |
| Root cron/timer/service | Caller, writable component, trigger | [root-run](root-run.md) |
| Writable privileged destination | Process follows/overwrites it | [file-write](file-write.md) |
| Docker/LXD/socket | Group, socket ACL, rootful daemon | [groups-and-nfs](groups-and-nfs.md) |
| NFS export | `no_root_squash`, write access | [NFS](groups-and-nfs.md#nfs) |
| Saved credential | Account, service, reuse | [creds](#users-homes-credentials) |
| Kernel/package candidate | Exact build, arch, patch state | [kernel-checks](kernel-checks.md) |
