# 07 · Password Attacks & Cracking

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Identify hash/credential type and account before choosing a mode or service.

| Material or access | Quick fit check | Details |
| --- | --- | --- |
| Unknown hash | Check its full format, source, and likely type before choosing a mode. | [Hash notes](passwords/cracking.md#identify-the-hash) |
| Offline hash | Confirm the mode and formatting with one known example, then use a targeted wordlist or rule. | [Offline cracking](passwords/cracking.md) |
| Archive or key file | Convert it with the matching `*2john` tool, then crack the resulting hash. | [John and conversions](passwords/cracking.md#john) |
| NT hash | Check whether the target service accepts NTLM and whether the account has access there. | [NT vs NetNTLMv2](passwords/cracking.md#identify-the-hash) |
| NetNTLMv2 response | Crack it offline; it is not an NT hash for Pass the Hash. | [Hash notes](passwords/cracking.md#identify-the-hash) · [Capture with `ntlm_theft`](windows/ntlm-capture.md) |
| Online login | Check lockout policy, account scope, response baseline, and token handling first. | [Online login checks](passwords/online-logins.md) |
| Credentials found | Test plausible services, then return to [Recon](01-recon.md), [Foothold](02-foothold.md), or [AD](05-active-directory.md). | [Service triage](enum/service-triage.md) |

Every login looks valid? Recheck failure string and per-request token.
