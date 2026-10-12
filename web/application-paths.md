# Application entry points and path filters

## Path normalization
Compare each variant against the canonical path and a missing path.

| Clue | Try |
| --- | --- |
| Tomcat / Spring path filter | `..;/` or `/;/` segment |
| Nginx `alias` | `/x../` vs `/x/` (only if alias/location boundaries fit) |
| Filter strips `../` | `%2e%2e%2f`, `..%2f`, `....//`, double encoding, one at a time |
| Proxy trusts forwarded headers | `X-Forwarded-For`, `X-Original-URL`, `X-Rewrite-URL` on admin-only paths |

## Known application entry points
| App | Check |
| --- | --- |
| WordPress | Plugin versions, readable `wp-config.php`, admin theme editor |
| Tomcat | `/manager/html`, accepted creds, WAR deploy allowed |
| Jenkins | `/script` reachable → Groovy `println "id".execute().text` |
| Exposed Git | `.git/` readable → source, creds |
