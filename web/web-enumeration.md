# Web enumeration

Use the discovered hostname for Host/SNI. Check source, JS, `robots.txt`, `sitemap.xml`, `.git/`, backups. Version clues: [fingerprinting.md](fingerprinting.md)

## Quick look
```bash
whatweb http://<IP>
curl -sI http://<IP>
```

## Content and parameters
```bash
feroxbuster -u http://<IP> -w /usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt -x php,txt,html,bak,zip
ffuf -u http://<IP>/FUZZ -w <wordlist> -e .php,.txt,.bak -mc all -fc 404
```
Get the baseline size first, then `-fs`:

```bash
ffuf -u http://<IP> -H 'Host: FUZZ.<DOMAIN.TLD>' -w <subdomain-list> -fs <baseline-size>
ffuf -u 'http://<IP>/page.php?FUZZ=test' -w <parameter-list> -fs <baseline-size>
```

## CMS
```bash
wpscan --url http://<IP> --enumerate u,vp,vt
droopescan scan drupal -u http://<IP>
joomscan -u http://<IP>
```
- Confirm scanner hits manually.
- Repeat path/function checks after login or role change. Input checks: [02-foothold.md](../02-foothold.md)
