# NT hashes and NetNTLMv2

```bash
hashcat -m 1000 nt.txt /usr/share/wordlists/rockyou.txt
hashcat -m 5600 netntlmv2.txt /usr/share/wordlists/rockyou.txt
```
- NT hash: crack, or Pass the Hash to a compatible NTLM service.
- NetNTLMv2: crack only. Relay needs a fresh live exchange → [ad/ntlm-relay](../ad/ntlm-relay.md).
- Local SAM/LSA/LSASS → [credential-access](credential-access.md). Induced client auth → [ntlm-capture](ntlm-capture.md).

| Material | Next |
| --- | --- |
| NT hash | Match local/domain scope and service auth policy |
| NetNTLMv2 response | Crack offline, not Pass the Hash |
| DCC/DCC2 (cached domain) | Crack offline, not a reusable NT key |
| AES Kerberos key | Kerberos auth only |
| TGT / service ticket | Specific principal/service → [ad/tickets](../ad/tickets.md) |
