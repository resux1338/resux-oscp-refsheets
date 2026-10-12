# Web authentication and access control

GraphQL: [graphql.md](graphql.md). Deserialization parser clues: [insecure-deserialization.md](insecure-deserialization.md)

| Check | Do | Real finding only if |
| --- | --- | --- |
| IDOR | 2 accounts: swap only the object ID; compare read + write + stored result; repeat unauthenticated | Cross-user/privilege boundary crossed (`200` alone isn't proof) |
| Mass assignment | Add `role` / `ownerId` to a normal update | Server persisted it |
| OAuth/OIDC | Record `redirect_uri`, `state`, `nonce`; change `redirect_uri`; replay callback in another session | Missing/mismatched state accepted, or code/token reaches your host |
| SAML | Check signature, issuer, destination, audience, timestamps, `InResponseTo`; test `RelayState` allowlist | A second account/SP endpoint accepts it |

## JWT
Decode header/payload; test `alg:none`, weak HMAC secret, public-key/HMAC confusion.

```bash
hashcat -m 16500 jwt.txt rockyou.txt
```
