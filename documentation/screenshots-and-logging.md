# Screenshots and terminal logging

Hotkey screenshots into the right Obsidian folder, plus a log per terminal.

## Folder layout
Make the folders in the warmup. `<OCTET>` (last IP octet) must be unique across all sets.
```bash
mkdir -p ~/exam/ADset/{150,151,152}/screenshots
mkdir -p ~/exam/standalone/{154,155,156}/screenshots
```
- Open `~/exam` as the Obsidian vault. Notes sit next to `screenshots/`.

## Screenshot hotkey
```bash
sudo apt install scrot xclip
mkdir -p ~/bin && cp scripts/shot.sh ~/bin/ && chmod +x ~/bin/shot.sh
echo <OCTET> > ~/exam/.current
```
Bind in Settings → Keyboard (GNOME: Custom Shortcuts, XFCE: Application Shortcuts):

| Hotkey | Command |
| --- | --- |
| `Ctrl+Alt+S` | `~/bin/shot.sh` |
| `Ctrl+Alt+Shift+S` | `~/bin/shot.sh -l` (asks for a label, e.g. `proof-root`) |

- Switch target: `echo <OCTET> > ~/exam/.current`. The notification shows the saved path: check it.
- Captures the focused window and copies `![[file.png]]` for Obsidian. X11 only.
- Test one shot in the warmup. Error notification = no `.current`, folder missing, or octet not unique.

## Terminal logging
```bash
script -a -f ~/exam/<SET>/<OCTET>/term-$(date +%H%M).log
```
```bash
tmux pipe-pane -o 'cat >> ~/exam/<SET>/<OCTET>/tmux-#S-#I-#P.log'
```
Strip colour codes from a log:
```bash
sudo apt install colorized-logs
ansi2txt < term.log > term.txt
```
- Start the log before the first command on a target. `exit` ends a `script` log.

## Reverse shell screenshots
The shot must show the target shell and its IP in one window.
```bash
ip a; hostname; id
```
```cmd
ipconfig & hostname & whoami
```
- Your Kali prompt alone does not prove which machine it is.
