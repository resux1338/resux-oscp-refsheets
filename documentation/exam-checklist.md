# Exam documentation checklist

Per OffSec OSCP+ exam guide: no proof screenshot, no points for that machine. Check the live guide for changes.

## Proof file (every local.txt / proof.txt)
One screenshot with all three: file contents, target IP, interactive shell.
```bash
ip a; hostname; id; cat <PATH>/proof.txt
```
```cmd
ipconfig & hostname & whoami & type <PATH>\proof.txt
```
```powershell
ipconfig; hostname; whoami; type <PATH>\proof.txt
```
- Interactive shell only: a web shell or one-shot RCE gives zero points for the machine.
- Read the file from its original location (full path visible). Do not `clear` first.
- Submit the contents in the exam control panel too. It does not say whether they are correct.

## Per machine
| Item | Done when |
| --- | --- |
| `local.txt` | Screenshot + control panel submit |
| `proof.txt` | Screenshot + control panel submit |
| Windows privilege | Shell as SYSTEM, Administrator or an admin user |
| Linux privilege | Root shell |
| Steps | Every command and its output, replicable |
| Report order | Machines in the order you want them graded |

## Report content
| Item | Needs |
| --- | --- |
| Commands | Every attack step, command and console output |
| Unmodified exploit | URL only, no code |
| Modified exploit | Modified code, original URL, shellcode command, highlighted changes, why |
| Scripts / PoCs | Pasted as text inside the PDF |
| Credentials | Where found, where used |

- Once the report is submitted it is final: nothing missing gets requested.

## Submission
```bash
sudo 7z a OSCP-<OSID>-Exam-Report.7z OSCP-<OSID>-Exam-Report.pdf
md5sum OSCP-<OSID>-Exam-Report.7z
```
| Check | Rule |
| --- | --- |
| File | PDF only inside the archive |
| Names | `OSCP-OS-XXXXX-Exam-Report.pdf` / `.7z`, case-sensitive |
| Archive | `.7z`, no password, ≤ 200 MB |
| Upload | https://upload.offsec.com within 24 h of exam end |
| Verify | MD5 shown on the site matches `md5sum`, then click "Submit File" |

- Windows 11 upload errors: upload from a Kali VM.

## Exam facts
| Item | Value |
| --- | --- |
| Time | 23 h 45 min, then 24 h for the report |
| Points | 3 standalone × 20 (10 access + 10 privesc), AD set 40 (10 + 10 + 20); pass at 70 |
| AD set | Starts with a username and password |
| Reverts | 24, reset once |
| Downloads | Nothing from the exam environment unless needed to compromise a machine; delete afterwards |

---
<sub>Source: [OffSec OSCP+ Exam Guide](https://help.offsec.com/hc/en-us/articles/360040165632-OSCP-Exam-Guide), read 2026-10-12 (article last updated 2026-10-12). Recheck it before the exam.</sub>
