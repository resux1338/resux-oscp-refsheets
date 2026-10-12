# Technology and version fingerprinting

Fingerprint the application, framework and front web server separately. Note hostname, port, scheme and redirect chain with each observation.

## Identify the service
```bash
nmap -Pn -sV -p <PORT> <IP>
```
- Port number is a hint only. Non-HTTP: [service-triage.md](../enum/service-triage.md)

## Collect web clues
```bash
URL='http://<IP>:<PORT>/'
whatweb -v "$URL"
curl -sS -D headers.txt -o page.html "$URL"
curl -sS -L -D redirects.txt -o /dev/null "$URL"
curl -sS -D - -o /dev/null "${URL}missing-page-12345"
```
Vhost over HTTPS (sets SNI):

```bash
curl --resolve <DOMAIN.TLD>:443:<IP> -k -sS -D - -o page.html https://<DOMAIN.TLD>/
```
- Also check page source, DevTools: scripts, cookies, **local storage**, network requests.

| Clue | Tells you | Limit |
| --- | --- | --- |
| `Server`, `X-Powered-By`, error pages | Server/framework family | Proxy may rewrite |
| Cookie / local-storage names | Framework or CMS | Can be customized |
| Generator tags, asset paths | CMS, theme, library | Theme version ≠ CMS version |
| Admin/login redirects | Application family | Rarely a release |
| Static files, manifests, source maps | Bytes to diff against tagged releases | Same file across many releases |
| Bundle / cache-buster tokens | Version-derived hash | Find all hash inputs first |

## Narrow the version
1. Product from ≥2 independent clues.
2. Explicit version in app output, else versioned asset URLs.
3. Diff a fetched static file against candidate release tags; a match gives a range.
4. Hash/cache-buster: read the product source for its inputs, hash candidate versions.
5. Confirm an exact version with a second signal.

## Example: Umbraco 10 cache buster
- `/umbraco` = backoffice. `ls.umbVersion` is a local-storage key (not a cookie). `/sb/` = Smidge bundle (Umbraco 9–13).
- Value = SHA-1 of `<version>.<runtime level>.<Smidge cache buster>`. The URL's leading `v` is a prefix; leave it off.

```text
ls.umbVersion = 1e39f354c707a49ed7f69f3926d55eb08f384c01
/sb/umbraco-backoffice-init-css.css.v2c03326042b3360461829471ffe4c8c38a8cc7b9
```
```bash
printf '%s' '10.3.2.Run.2c03326042b3360461829471ffe4c8c38a8cc7b9' | sha1sum
# 1e39f354c707a49ed7f69f3926d55eb08f384c01  -
```
```python
from hashlib import sha1

stored = "1e39f354c707a49ed7f69f3926d55eb08f384c01"
bundle = "2c03326042b3360461829471ffe4c8c38a8cc7b9"

for major in range(9, 14):
    for minor in range(30):
        for patch in range(50):
            version = f"{major}.{minor}.{patch}"
            if sha1(f"{version}.Run.{bundle}".encode()).hexdigest() == stored:
                print(version)  # 10.3.2
```
- No match → stale browser value, different deployment, other runtime level, custom build.
- With backoffice access, authenticated server variables include `application.version`.
