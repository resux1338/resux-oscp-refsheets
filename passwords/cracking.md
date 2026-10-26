# Offline cracking and wordlists

## Identify the hash
```bash
hashid '<HASH>'
hash-identifier
nth '<HASH>'
```
NT hash from a known password (for Pass the Hash / ticketer / `-k`; `hashlib` md4 can be missing with OpenSSL 3):
```bash
python3 -c 'from impacket.ntlm import compute_nthash; print(compute_nthash("<PW>").hex())'
```
- NT hash = "the NTLM hash": crack, or Pass the Hash on an NTLM service. NetNTLMv2 is crack-only, not passable.
- Verify the mode against the hash format (`hashcat --example-hashes`) before a long run.

## hashcat
```bash
hashcat -m <MODE> hashes.txt /usr/share/wordlists/rockyou.txt
hashcat -m <MODE> hashes.txt /usr/share/wordlists/rockyou.txt -r /usr/share/hashcat/rules/best64.rule
hashcat --show -m <MODE> hashes.txt
```

| Mode | Hash |
| --- | --- |
| 0 / 100 / 1400 / 1700 | MD5 / SHA1 / SHA256 / SHA512 |
| 500 / 1800 / 3200 | md5crypt `$1$` / sha512crypt `$6$` / bcrypt |
| 1600 | Apache `$apr1$` MD5 (htpasswd) |
| 400 | phpass (WordPress/phpBB) |
| 10 / 20 | md5($pass.$salt) / md5($salt.$pass) |
| 10000 | Django (PBKDF2-SHA256) |
| 1000 | NTLM |
| 5500 | NetNTLMv1 / NetNTLMv1+ESS |
| 5600 | NetNTLMv2 |
| 13100 | Kerberoast TGS (etype 23) |
| 19600 / 19700 | Kerberoast TGS etype 17 / 18 (AES) |
| 18200 | AS-REP (etype 23) |
| 19800 / 19900 | Kerberos pre-auth etype 17 / 18 |
| 131 / 1731 | MSSQL (2000) / MSSQL (2012, 2014) |
| 300 | MySQL 4.1/5 |
| 7300 | IPMI2 RAKP HMAC-SHA1 |
| 13400 | KeePass (KDBX) |
| 22921 | SSH private key (`$6$`) |
| 13000 | RAR5 |
| 17200 / 13600 | PKZIP / WinZip |
| 16500 | JWT |

## Attack modes
```bash
hashcat -a 0 -m <MODE> hashes.txt wordlist.txt                       # straight (default)
hashcat -a 3 -m <MODE> hashes.txt '?u?l?l?l?d?d?d?d!'                # brute-force mask
hashcat -a 6 -m <MODE> hashes.txt wordlist.txt '?d?d'                # hybrid: wordlist + mask appended
hashcat -a 7 -m <MODE> hashes.txt '?d?d' wordlist.txt                # hybrid: mask + wordlist prepended
hashcat -a 0 -m <MODE> hashes.txt wordlist.txt -j '$2$0$2$6$!'       # quick inline rule: append "2026!" to every word
hashcat -m <MODE> --username hashes.txt wordlist.txt                  # hashes.txt is user:hash per line
```
- `-a 3` mask charsets: `?l` lower, `?u` upper, `?d` digit, `?s` special, `?a` all. Order the mask to match the policy you're guessing against (`?u?l?l?l?d?d?d?d!` = Capital + 3 lower + 4 digits + `!`).
- `-j`/`--rule-left`: one literal rule inline, no rule file needed — faster than writing a one-line `.rule` file for a single quick guess (year + `!`, etc.).
- `--username`: strips the username column before hashing; without it, hashcat tries to crack `user:hash` as one string and fails.

## john
```bash
john --wordlist=/usr/share/wordlists/rockyou.txt hashes.txt
john --show hashes.txt
```
Convert to a john hash:
```bash
ssh2john id_rsa > h
keepass2john f.kdbx > h
zip2john f.zip > h
office2john doc.docx > h
pdf2john f.pdf > h
gpg2john <FILE> > h
john --wordlist=/usr/share/wordlists/rockyou.txt h
```

## /etc/shadow
```bash
unshadow /etc/passwd /etc/shadow > combined
john --wordlist=/usr/share/wordlists/rockyou.txt combined
```
- Or `hashcat -m 1800` for `$6$`.

## Wordlist mangling
```bash
cewl http://<IP> -w words.txt -d 3 -m 5
hashcat --stdout words.txt -r /usr/share/hashcat/rules/best64.rule | sort -u > big.txt
./username-anarchy <FIRSTNAME> <LASTNAME>
```
