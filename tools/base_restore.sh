#!/usr/bin/env bash
set -euo pipefail
backup=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
game=$(cd -- "${1:?Usage: bash restore.sh /path/to/GTA}" && pwd)
[[ "$(dirname -- "$(dirname -- "$backup")")" == "$game" ]] || { echo 'Backup belongs to a different game.' >&2; exit 1; }
if pgrep -ix 'gta_sa.exe|samp.exe' >/dev/null; then echo 'Close GTA and SA-MP first.' >&2; exit 1; fi
# Never remove or replace files modified after installation.
while read -r hash path; do
    current="$game/$path"
    while [[ "$current" != "$game" ]]; do
        [[ ! -L "$current" ]] || { echo "Symlink refused: $current" >&2; exit 1; }
        current=$(dirname -- "$current")
    done
done < "$backup/FILES.sha256"
(cd "$game" && sha256sum --check "$backup/FILES.sha256")
while IFS= read -r path; do
    if [[ -f "$backup/original/$path" ]]; then cp -p -- "$backup/original/$path" "$game/$path"; else rm -f -- "$game/$path"; fi
done < "$backup/written.txt"
for owned in moonloader/lib/horizonbase moonloader/resource/horizonbase; do
    if [[ -d "$game/$owned" ]]; then find "$game/$owned" -depth -type d -empty -delete; fi
done
echo 'Base files restored. Player settings and unrelated files were preserved; backup retained.'
