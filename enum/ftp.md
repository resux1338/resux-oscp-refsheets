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
