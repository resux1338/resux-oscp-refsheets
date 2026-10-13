# 04 · Windows Privilege Escalation

> Part of the **OSCP/OSCP+ cheatsheet** | [← back to index](README.md)

Token/build first; then exact right, writable path, trigger. Start: [Windows enumeration](windows/enumeration.md).

```powershell
whoami /all
systeminfo
```

| Possible path | Quick fit check | Details |
| --- | --- | --- |
| Token privilege | In this token? Required service present? | [Token rights](windows/token-groups.md) · [Potato](windows/potato.md) |
| Privileged group | Scope, active token, object right | [Local token rights](windows/token-groups.md) · [AD/DC groups](ad/privileged-groups.md) |
| Rare privilege (Restore, TakeOwnership, LoadDriver, ManageVolume, Debug) | Held in token, writable target, trigger | [Token rights](windows/token-groups.md#serestoreprivilege) |
| Service binary | Service account, path, file rights, restart | [Binary hijacking](windows/service-binary-hijacking.md) |
| Service configuration | Can you change `binPath` and restart? | [Service permissions](windows/service-permissions.md) |
| Unquoted service path | Spaces, unquoted, writable prefix? | [Unquoted paths](windows/unquoted-service-paths.md) |
| DLL load | Missing or writable DLL path; trigger | [DLL hijacking](windows/dll-hijacking.md) |
| Task or autorun | Consumer token, action, ACL, trigger | [Tasks and autoruns](windows/scheduled-tasks-and-autoruns.md) |
| Installer policy | Machine and user policy values | [Installer policy](windows/services.md#installer-policy) |
| Credential or saved logon | Stored creds, configs, history | [Credential checks](windows/credentials.md) |
| Local hash material | Extraction rights; NT hash vs NetNTLM | [Credential access](windows/credential-access.md) · [NT hashes](windows/ntlm.md) |
| Admin account, no privileges | Medium integrity, filtered token | [UAC](windows/uac.md) |
| Application or user secret store | KeePass, browser, WinSCP/VNC/PuTTY, IIS config | [Credential stores](windows/credential-stores.md) |
| Script/exe refused | Policy, language mode, AppLocker, AV, AMSI, architecture | [Execution and defenses](windows/execution-and-defenses.md) |
| Tool blocked or missing | File, runtime, Defender status | [Tool troubleshooting](windows/enumeration.md#tool-troubleshooting) |

Check host ACLs and service state before replacing anything.
