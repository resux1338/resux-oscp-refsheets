# 02 · Foothold: Shells, Web & Exploits

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Pick the row matching the input; compare against a normal request.

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| SQL input | Change one quote/condition; compare | [Manual SQLi](web/manual-sqli.md) |
| File path or include | Known readable file: content or evaluated? | [LFI and traversal](web/lfi.md) |
| Remote URL used as file | Serve a marker; PHP interpreted? | [RFI](web/rfi.md) |
| File upload | Find saved path; does it execute? | [Uploads](web/files-and-commands.md#file-upload) |
| Shell-backed input | Harmless command or delay vs baseline | [Command injection](web/files-and-commands.md#command-injection) |
| Template input | One arithmetic expression, then a second | [SSTI](web/ssti.md) |
| Server fetches a URL | Unique callback URL; check listener | [SSRF](web/ssrf.md) |
| XML parser | Does a controlled entity change output? | [XXE](web/xxe.md) |
| Serialized value | Identify format and parser first | [Insecure deserialization](web/insecure-deserialization.md) |
| API or auth boundary | Change one ID/role; compare as another user | [Authentication and access control](web/authentication.md) · [GraphQL](web/graphql.md) |
| NoSQL query input | Literal value vs operator | [NoSQL injection](web/nosql.md) |
| JWT | Decode; only server-accepted change counts | [JWT](web/authentication.md#jwt) |
| Browser-rendered input | Find output context; does it execute? | [XSS](web/xss.md) |
| Known app or path filter | Version, plugins, default access, normalization | [Application paths](web/application-paths.md) |
| Tomcat, Jenkins, WordPress, Joomla/Drupal, `.git`, WebDAV, CGI | Admin login or readable config; exact version | [Apps → code execution](web/cms-and-apps.md) |
| Database login (MySQL, PostgreSQL, Redis) | Role, file write, program execution | [DB → RCE](enum/databases-and-redis.md#from-database-access-to-code-execution) |
| Uncommon open port (VNC, Oracle, Mongo, Elasticsearch, memcached, Docker API) | Auth required? Data readable? | [Less common services](enum/exposed-services.md) |
| Public PoC | Exact version; read code first | [Public exploits](foothold/public-exploits.md) |
| User opens delivered content | Delivery path, client action, callback | [Client-side attacks and phishing](foothold/client-side-phishing.md) |

After code execution: `id`/`whoami` → [shell](foothold/shells.md) · [payload](foothold/shells.md#msfvenom-payloads) · [encoded PowerShell](foothold/shells.md#powershell--encodedcommand) · [bind shell](foothold/shells.md#bind-shell-outbound-traffic-blocked) · [transfer](foothold/file-transfer.md).
