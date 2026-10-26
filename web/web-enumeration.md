# Web enumeration

Use the discovered hostname for Host/SNI. Check source, JS, `robots.txt`, `sitemap.xml`, `.git/`, backups. Version clues: [fingerprinting.md](fingerprinting.md)

## Quick look
```bash
whatweb http://<IP>
curl -sI http://<IP>
```

## Wordlists
Under `/usr/share/seclists/Discovery/Web-Content/`:

| Use | List |
| --- | --- |
| first pass, fast | `common.txt` |
| directories | `raft-medium-directories.txt` |
| files | `raft-medium-files.txt` |
| bigger | `big.txt`, `raft-large-directories.txt` |
| classic | `/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt` |
| API paths | `api/api-endpoints.txt` |
| parameter names | `burp-parameter-names.txt` |
| leftovers | `quickhits.txt`, `Common-DB-Backups.txt` |

## Extensions
| Stack | `-x` / `-e` |
| --- | --- |
| PHP | `php,txt,html,bak` |
| IIS / ASP.NET | `aspx,asp,config,txt` |
| Java | `jsp,do,action,xml` |
| Backups | `bak,old,orig,swp,zip,tar.gz` and `~` suffix (`index.php.bak`, `config.php~`, `backup.zip`) |

- feroxbuster / gobuster `-x` take bare extensions (`php`); ffuf `-e` needs the dot (`.php`).

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

## Recursion, auth, filters
```bash
feroxbuster -u http://<IP> -w <wordlist> -d 3
feroxbuster -u http://<IP> -w <wordlist> -n
feroxbuster -u http://<IP> -w <wordlist> -H 'Cookie: <NAME>=<VALUE>' -C 404
ffuf -u http://<IP>/FUZZ -w <wordlist> -recursion -recursion-depth 2
ffuf -u http://<IP>/FUZZ -w <wordlist> -b '<NAME>=<VALUE>' -ac
ffuf -u http://<IP>/FUZZ -w <wordlist> -H 'Authorization: Bearer <TOKEN>' -fw <words> -fl <lines>
```
- feroxbuster `-d` depth, `-n` no recursion, `-C` filter status. ffuf `-recursion` needs the URL to end in `FUZZ`.
- ffuf filters: `-ac` auto-calibrate, `-fc` status, `-fs` size, `-fw` words, `-fl` lines. `-mc all` shows everything (pair with a filter).
- feroxbuster `-k` skips TLS verification; ffuf skips it by default.

## gobuster / nikto
Second opinion when ffuf output is noisy.
```bash
gobuster dir -u http://<IP> -w <wordlist> -x php,txt,bak
gobuster vhost -u http://<IP> --domain <DOMAIN.TLD> --append-domain -w <subdomain-list> --xl <baseline-size>
nikto -h http://<IP>
```
- `--xl` = exclude length. Without `--append-domain` the wordlist must hold full hostnames.

## API
```bash
ffuf -u http://<IP>/FUZZ -w /usr/share/seclists/Discovery/Web-Content/api/api-endpoints.txt -mc all -fc 404
ffuf -u http://<IP>/api/v1/FUZZ -w <wordlist> -mc all -fc 404
ffuf -u http://<IP>/api/v1/<ENDPOINT> -X POST -H 'Content-Type: application/json' -d '{"FUZZ":"test"}' -w <parameter-list> -fs <baseline-size>
curl -s -X OPTIONS -i http://<IP>/api/v1/<ENDPOINT>
```
- Version paths: `/api`, `/api/v1`, `/api/v2`, `/v1`, `/v2`. Try other methods (`-X POST|PUT|DELETE`) on each hit; `405` = path exists.
- Docs/leaks: `/swagger.json`, `/openapi.json`, `/swagger-ui/`, `/api-docs`, `/actuator`, `/actuator/env`, `/.well-known/`.

## HTTPS names
Cert SANs reveal vhosts; add them to `/etc/hosts`.
```bash
openssl s_client -connect <IP>:443 </dev/null 2>/dev/null | openssl x509 -noout -text | grep -E 'DNS:|CN ?='
```

## Through Burp
```bash
curl -x http://127.0.0.1:8080 -k http://<IP>/
feroxbuster -u http://<IP> -w <wordlist> --burp
ffuf -u http://<IP>/FUZZ -w <wordlist> -replay-proxy http://127.0.0.1:8080
```
```python
requests.get(url, proxies={"http": "http://127.0.0.1:8080", "https": "http://127.0.0.1:8080"}, verify=False)
```
- Send a baseline request to Repeater first. Intruder only where the rate is low (Community edition is throttled).
- `ffuf -replay-proxy` sends only matches to Burp; `-x` sends everything.

## CMS
```bash
wpscan --url http://<IP> --enumerate u,vp,vt
droopescan scan drupal -u http://<IP>
joomscan -u http://<IP>
```
- `vp`/`vt` vuln data only with `--api-token <TOKEN>` (free wpscan.com account).
- Confirm scanner hits manually.
- Repeat path/function checks after login or role change. Input checks: [02-foothold.md](../02-foothold.md)
