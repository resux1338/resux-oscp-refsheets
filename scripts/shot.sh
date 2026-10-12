#!/bin/bash
# Screenshot the focused window into ~/exam/<any set>/<octet>/screenshots/
#   shot.sh        save instantly
#   shot.sh -l     save, then ask for a label (zenity)
# Active target = last octet in ~/exam/.current   ->   echo 150 > ~/exam/.current
# The folder must already exist and the octet must be unique under ~/exam.
# Copies the Obsidian embed ![[file.png]] to the clipboard.

root=${EXAM_ROOT:-$HOME/exam}
fail() { notify-send -u critical "shot: $1" "${2:-}"; echo "shot: $1 ${2:-}" >&2; exit 1; }

[ -r "$root/.current" ] || fail "no target set" "echo <octet> > $root/.current"
oct=$(tr -d '[:space:]' < "$root/.current")
[ -n "$oct" ] || fail "no target set" "echo <octet> > $root/.current"

mapfile -t dirs < <(find "$root" -maxdepth 3 -type d -path "*/$oct/screenshots" 2>/dev/null)
[ "${#dirs[@]}" -eq 1 ] || fail "need exactly 1 folder for $oct, found ${#dirs[@]}" "*/$oct/screenshots under $root"
dir=${dirs[0]}

ts=$(date +%Y%m%d-%H%M%S)
out="$dir/$oct-$ts.png"
n=1; while [ -e "$out" ]; do n=$((n+1)); out="$dir/$oct-$ts-$n.png"; done

# Capture first: opening the label dialog would steal focus.
if command -v scrot >/dev/null; then
    scrot -u "$out"
elif command -v maim >/dev/null && command -v xdotool >/dev/null; then
    maim -i "$(xdotool getactivewindow)" "$out"
elif command -v gnome-screenshot >/dev/null; then
    gnome-screenshot -w -f "$out"
else
    fail "no screenshot tool" "sudo apt install scrot xclip"
fi
[ -s "$out" ] || fail "capture failed" "$out"

if [ "$1" = "-l" ]; then
    label=$(zenity --entry --title "shot label" --text "Label ($oct)" 2>/dev/null) || label=
    label=$(printf '%s' "$label" | tr -c 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')
    if [ -n "$label" ]; then
        new="${out%.png}-$label.png"
        mv -- "$out" "$new" && out=$new
    fi
fi

name=$(basename "$out")
embed="![[$name]]"
if command -v xclip >/dev/null; then printf '%s' "$embed" | xclip -selection clipboard
elif command -v xsel >/dev/null; then printf '%s' "$embed" | xsel -ib
elif command -v wl-copy >/dev/null; then printf '%s' "$embed" | wl-copy
fi

notify-send "shot saved" "${out#"$root"/}"
echo "$out"
