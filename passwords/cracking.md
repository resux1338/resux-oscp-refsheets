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
| 1000 | NTLM |
| 5600 | NetNTLMv2 |
| 13100 | Kerberoast TGS (etype 23) |
| 19600 / 19700 | Kerberoast TGS etype 17 / 18 (AES) |
| 18200 | AS-REP (etype 23) |
| 19800 / 19900 | Kerberos pre-auth etype 17 / 18 |
| 13400 | KeePass (KDBX) |
| 22921 | SSH private key (`$6$`) |
| 13000 | RAR5 |
| 17200 / 13600 | PKZIP / WinZip |
| 16500 | JWT |

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
