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
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.25.6.3.1.2    # software
snmpwalk -v2c -c public <IP> 1.3.6.1.4.1.77.1.2.25     # Windows users
snmpwalk -v2c -c public <IP> 1.3.6.1.2.1.6.13.1.3      # TCP ports
snmpwalk -v2c -c public <IP> NET-SNMP-EXTEND-MIB::nsExtendObjects
```
- Unknown MIB name → use numeric OID.
- Timeout → filtering, wrong community or version.
