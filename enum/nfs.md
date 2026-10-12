# NFS and RPCbind

## Exports
Blank `showmount` may still mean NFSv4-only. Privesc: [linux/groups-and-nfs.md](../linux/groups-and-nfs.md).

```bash
rpcinfo -p <IP>
showmount -e <IP>
```

## Mount
```bash
sudo mkdir -p /mnt/target-nfs
sudo mount -t nfs -o ro <IP>:/export /mnt/target-nfs
find /mnt/target-nfs -maxdepth 2 -type f -ls
stat -c '%u:%g %A %n' /mnt/target-nfs
sudo umount /mnt/target-nfs
```

| Mount fails | Check |
|---|---|
| Denied | export path, client allowlist |
| Hangs | NFS version, TCP/2049 |
| Path wrong | NFSv4 paths differ |
