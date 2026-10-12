# resux-oscp-refsheets

Offline command reference sheets for OSCP/OSCP+ and CPTS practice. Check the current [OffSec exam guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide) before the exam. Links: [REFERENCES.md](REFERENCES.md).

Got a shell or domain credential? Check the low-hanging fruit first:

| Access | First enumeration pass |
| --- | --- |
| Domain credential or domain-joined host | [Active Directory enumeration](ad/active-directory-enum.md) |
| Windows shell | [Windows host enumeration](windows/enumeration.md) |
| Linux shell | [Linux enumeration](linux/enumeration.md) |

| Phase | Quick reference |
| --- | --- |
| Methodology / assessment flow | [00-methodology.md](00-methodology.md) |
| Recon and enumeration | [01-recon.md](01-recon.md) |
| Foothold, shells, and web | [02-foothold.md](02-foothold.md) |
| Linux privilege escalation | [03-linux-privesc.md](03-linux-privesc.md) |
| Windows privilege escalation | [04-windows-privesc.md](04-windows-privesc.md) |
| Active Directory | [05-active-directory.md](05-active-directory.md) |
| Pivoting and tunneling | [06-pivoting.md](06-pivoting.md) |
| Password attacks and cracking | [07-password-attacks.md](07-password-attacks.md) |

| Section | Detailed pages |
| --- | --- |
| Linux | [Sudo](linux/sudo.md) · [SUID and capabilities](linux/suid-and-capabilities.md) |
| Windows | [Scheduled tasks and autoruns](windows/scheduled-tasks-and-autoruns.md) |
| AD | [Delegation](ad/delegation.md) · [LAPS and gMSA](ad/managed-credentials.md) · [Privileged groups](ad/privileged-groups.md) · [NTLM relay](ad/ntlm-relay.md) |

## Placeholders
| Placeholder | Meaning |
| --- | --- |
| `<IP>` · `<KALI>` · `<SUBNET>` · `<PORT>` | Target IP, attacker IP, subnet, port |
| `<DOMAIN>` · `<DOMAIN.TLD>` | NetBIOS name · DNS name |
| `<DC-IP>` · `<DC-FQDN>` · `<FQDN>` | Domain controller IP/FQDN · other host FQDN |
| `<USER>` · `<PW>` · `<NT>` | Username, password, NT hash |
| `<HOSTNAME>` · `<COMPUTER>` · `<TARGET>` · `<SERVICE>` · `<SVC>` · `<GMSA>` · `<GROUP>` · `<SHARE>` | Object names |
| `<IMPERSONATE>` · `<LOCAL-USER>` | Account to impersonate · local account |
| `<AES256-KEY>` · `<PFX>` · `<CA-FQDN>` · `<DLL-PATH>` · `<CONSOLE-PORT>` · `<SOURCE-IP>` | Key, certificate file, CA host, DLL path, relay console port, source host |

Check local tool help for version-specific flags. Helpers: [scripts/](scripts/README.md).
