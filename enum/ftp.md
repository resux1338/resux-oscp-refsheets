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
