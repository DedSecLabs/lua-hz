#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
game=$(cd -- "${1:?Usage: bash install.sh /path/to/clean/GTA}" && pwd)
if pgrep -ix 'gta_sa.exe|samp.exe' >/dev/null; then echo 'Close GTA and SA-MP first.' >&2; exit 1; fi
if [[ -e "$game/moonloader/HorizonBase.lua" || -e "$game/moonloader/lib/horizonbase" || -e "$game/moonloader/resource/horizonbase" || -e "$game/LuaHZLoading.asi" ]]; then
    echo 'Use a separate clean game copy; LuaHZ files already exist here.' >&2; exit 1
fi
(cd "$root/payload" && sha256sum --check "$root/FILES.sha256")
(cd "$game" && sha256sum --check "$root/PREREQUISITES.sha256")
for path in moonloader/lib/moonloader.lua moonloader/lib/vkeys.lua moonloader/lib/windows/message.lua moonloader/lib/mimgui/init.lua moonloader/lib/mimgui/cimguidx9.dll; do
    [[ -f "$game/$path" ]] || { echo "Missing prerequisite: $path" >&2; exit 1; }
done
# Reject links before writing through any target parent directory.
while read -r hash path; do
    current="$game/$path"
    while [[ "$current" != "$game" ]]; do
        [[ ! -L "$current" ]] || { echo "Symlink target refused: $current" >&2; exit 1; }
        current=$(dirname -- "$current")
    done
    [[ ! -d "$game/$path" ]] || { echo "File/directory collision: $path" >&2; exit 1; }
done < "$root/FILES.sha256"
[[ ! -L "$game/LuaHZ-backups" ]] || { echo 'Symlink backup directory refused.' >&2; exit 1; }
mkdir -p "$game/LuaHZ-backups"
backup=$(mktemp -d "$game/LuaHZ-backups/base-XXXXXXXX")
cp -- "$root/FILES.sha256" "$backup/FILES.sha256"
cp -- "$root/restore.sh" "$backup/restore.sh"
touch "$backup/written.txt"
rollback() {
    while IFS= read -r path; do
        if [[ -f "$backup/original/$path" ]]; then cp -- "$backup/original/$path" "$game/$path"; else rm -f -- "$game/$path"; fi
    done < "$backup/written.txt"
    for owned in moonloader/lib/horizonbase moonloader/resource/horizonbase; do
        if [[ -d "$game/$owned" ]]; then find "$game/$owned" -depth -type d -empty -delete; fi
    done
    echo "Installation failed; original files restored. Backup: $backup" >&2
}
trap rollback ERR
while read -r hash path; do
    if [[ -e "$game/$path" ]]; then
        mkdir -p -- "$backup/original/$(dirname -- "$path")"
        cp -p -- "$game/$path" "$backup/original/$path"
    fi
    mkdir -p -- "$game/$(dirname -- "$path")"
    printf '%s\n' "$path" >> "$backup/written.txt"
    cp -- "$root/payload/$path" "$game/$path"
done < "$root/FILES.sha256"
(cd "$game" && sha256sum --check "$root/FILES.sha256")
trap - ERR
echo "Installed. Recovery: bash '$backup/restore.sh' '$game'"
echo 'Launch Horizon from SA-MP in this game copy. F9: settings; I: stats; X: cruise.'
