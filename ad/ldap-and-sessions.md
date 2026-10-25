# LDAP, hosts, and sessions

## Kali baseline (known account)
```bash
nxc smb <DC-IP> -u <USER> -p '<PW>' --shares --users --groups --pass-pol
nxc smb <DC-IP> -u <USER> -p '<PW>' --rid-brute
ldapdomaindump -u '<DOMAIN>\\<USER>' -p '<PW>' <DC-IP>
```

## Build users.txt
```bash
nxc smb <DC-IP> -u <USER> -p '<PW>' --users 2>/dev/null \
  | awk '/-Username-/{f=1;next} /Enumerated/{f=0} f{print $5}' | sort -u > users.txt
nxc smb <DC-IP> -u <USER> -p '<PW>' --rid-brute 2>/dev/null \
  | awk '/SidTypeUser/{split($6,a,"\\"); print a[2]}' | grep -v '\$$' | sort -u > users.txt
```
- `--users` denied (guest / null) → `--rid-brute` often still works.
- `--rid-brute` lists machine accounts (`HOST$`); the `grep` drops them. `--users` already skips them.
- Hash instead of password: `-H '<NT>'`; machine account: `-u '<COMPUTER>$'`.

Anonymous RPC, then `enumdomusers`, `enumdomgroups`:
```bash
rpcclient -U '' -N <DC-IP>
kerbrute userenum -d <DOMAIN.TLD> --dc <DC-IP> users.txt
```
- `kerbrute` is not in Kali's repos: download the release binary.

## LDAP from PowerShell (no AD module)
```powershell
$PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
$DN = ([adsi]'').distinguishedName
$LDAP = "LDAP://$PDC/$DN"
$entry = New-Object System.DirectoryServices.DirectoryEntry($LDAP)
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter = "(samAccountType=805306368)"
$searcher.FindAll()
```
Reusable:
```powershell
function LDAPSearch {
    param([string]$LDAPQuery)
    $PDC = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name
    $DN = ([adsi]'').distinguishedName
    $entry = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$PDC/$DN")
    $searcher = New-Object System.DirectoryServices.DirectorySearcher($entry, $LDAPQuery)
    $searcher.FindAll()
}

LDAPSearch -LDAPQuery "(objectClass=group)"
```
- Narrow with a base such as `CN=Users,$DN`. Follow nested groups via `member`.

## Hosts and sessions
```powershell
. .\PowerView.ps1
Get-NetComputer | Select-Object dnshostname,operatingsystem,operatingsystemversion
Get-NetUser | Select-Object samaccountname,description
Find-LocalAdminAccess
Get-NetSession -ComputerName <FQDN> -Verbose
```
```cmd
PsLoggedon.exe \\<FQDN>
```
- `Find-LocalAdminAccess` is domain-wide: pass a smaller host set when needed.
- `Get-NetSession` = resource sessions; PsLoggedOn needs remote registry. Empty/denied ≠ nobody logged on (your own query may show).
