# 07 · Password Attacks & Cracking

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Identify hash/credential type and account before choosing a mode or service.

| Material or access | Quick fit check | Details |
| --- | --- | --- |
| Unknown hash | Full format, source, likely type | [Hash notes](passwords/cracking.md#identify-the-hash) |
| Offline hash | Test mode on a known example | [Offline cracking](passwords/cracking.md) |
| Archive or key file | `*2john` convert, then crack | [John and conversions](passwords/cracking.md#john) |
| NT hash | Service accepts NTLM? Account has access? | [NT vs NetNTLMv2](passwords/cracking.md#identify-the-hash) |
| NetNTLMv2 response | Crack offline; not passable | [Hash notes](passwords/cracking.md#identify-the-hash) · [Capture with `ntlm_theft`](windows/ntlm-capture.md) |
| Online login | Lockout, scope, baseline, token first | [Online login checks](passwords/online-logins.md) |
| Credentials found | Test services; back to Recon/Foothold/AD | [Service triage](enum/service-triage.md) · [Recon](01-recon.md) · [Foothold](02-foothold.md) · [AD](05-active-directory.md) |

Every login looks valid? Recheck failure string and per-request token.
