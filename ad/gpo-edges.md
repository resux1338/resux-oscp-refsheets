# Reading GPO edges

`GPLink` = GPO applies there. Needs edit rights on the GPO object and its SYSVOL folder + effective scope.

| Edge | Check next |
| --- | --- |
| `GenericWrite` / `GenericAll` on a GPO | Can you edit both the AD object and its SYSVOL directory? |
| `WriteDACL` / `WriteOwner` on a GPO | Can you grant yourself the edit right? |
| `GPLink` to an OU/domain | Target computer in scope after link state, inheritance, filtering? |
| `WriteGPLink` on an OU/domain | Is there also a GPO you control and can link? |

- Note GUID, `gPCFileSysPath`, version, extensions, link order. Confirm user vs computer policy target.

```powershell
Import-Module GroupPolicy
Get-GPO -Guid '<GPO-GUID>' -Domain '<DOMAIN.TLD>' -Server '<DC-FQDN>' |
    Format-List DisplayName,Id,GpoStatus,Owner,ComputerVersion,UserVersion,WmiFilter
Get-GPOReport -Guid '<GPO-GUID>' -ReportType Xml -Path '.\gpo-before.xml' -Domain '<DOMAIN.TLD>' -Server '<DC-FQDN>'
Backup-GPO -Guid '<GPO-GUID>' -Path '.\gpo-backup' -Domain '<DOMAIN.TLD>' -Server '<DC-FQDN>'
Get-GPInheritance -Target '<OU-OR-DOMAIN-DN>' -Domain '<DOMAIN.TLD>' -Server '<DC-FQDN>' |
    Format-List GpoInheritanceBlocked,GpoLinks,InheritedGpoLinks
```
- `Backup-GPO` needs the output folder to exist (`New-Item -ItemType Directory .\gpo-backup`).
