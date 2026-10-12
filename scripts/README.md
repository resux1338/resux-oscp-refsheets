# Scripts

[← Repository index](../README.md)

| Helper | Purpose | Related notes |
| --- | --- | --- |
| [Find-ExecutableReferences.ps1](Find-ExecutableReferences.ps1) | Finds visible services, scheduled tasks, and processes that reference an executable filename or path. | [DLL hijacking checks](../windows/dll-hijacking.md) |
| [shot.sh](shot.sh) | Screenshots the focused window into `~/exam/*/<OCTET>/screenshots/`; copies the Obsidian embed. | [Screenshots and logging](../documentation/screenshots-and-logging.md) |
| [vba_chunks.py](vba_chunks.py) | Splits a UTF-16LE Base64 PowerShell command into VBA string assignments. | [Office VBA delivery](../foothold/client-side-phishing.md#office-vba-document) |

## Find executable references

```powershell
.\Find-ExecutableReferences.ps1 'custom.exe'
.\Find-ExecutableReferences.ps1 'C:\Path\To\custom.exe'
```

Read-only. Access restrictions can hide results: empty ≠ no reference.

## VBA command chunks

```bash
python3 scripts/vba_chunks.py
python3 scripts/vba_chunks.py '<UTF-16LE-BASE64-COMMAND>'
```

No argument: prompts for the command, or pipe it on stdin. Prints `cmd = cmd & "..."` lines.

## Screenshot hotkey

```bash
echo <OCTET> > ~/exam/.current
~/bin/shot.sh
~/bin/shot.sh -l
```

Setup and hotkey binding: [Screenshots and logging](../documentation/screenshots-and-logging.md).
