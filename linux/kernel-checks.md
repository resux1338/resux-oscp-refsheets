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
