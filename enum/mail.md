# SMTP, IMAP, and POP3

## SMTP: 25, 465, 587
```bash
nmap -p25,587 --script smtp-commands <IP>
smtp-user-enum -M VRFY -U <users-file> -t <IP>
openssl s_client -starttls smtp -connect <IP>:587 -crlf -quiet
openssl s_client -connect <IP>:465 -crlf -quiet
```
```text
EHLO <DOMAIN.TLD>
VRFY <USER>
QUIT
```
- 465 = implicit TLS; 25/587 = STARTTLS if advertised.
- `530` at `RCPT TO` → auth required first.
- Authenticated send / stop conditions: [client-side-phishing](../foothold/client-side-phishing.md)

Known creds (stops before `DATA`):

```bash
swaks --server <IP> --auth LOGIN \
  --auth-user '<USER>@<DOMAIN.TLD>' --auth-password \
  --protect-prompt --auth-hide-password \
  --from '<USER>@<DOMAIN.TLD>' --to 'test@<DOMAIN.TLD>' --quit-after RCPT
```

## IMAP: 143, 993
```bash
openssl s_client -connect <IP>:993 -crlf -quiet
openssl s_client -starttls imap -connect <IP>:143 -crlf -quiet
```
```text
a1 CAPABILITY
a2 LOGIN "<USER>" "<PW>"
a3 LIST "" "*"
a4 SELECT INBOX
a5 SEARCH ALL
a6 FETCH 1 BODY.PEEK[]
a7 LOGOUT
```

## POP3: 110, 995
```bash
openssl s_client -connect <IP>:995 -crlf -quiet
openssl s_client -starttls pop3 -connect <IP>:110 -crlf -quiet
```
```text
USER <USER>
PASS <PW>
STAT
LIST
RETR 1
QUIT
```
- Use `RETR`, not `DELE`.
