#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/poulpoints-desktop"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BUNDLE="${1:-$HERE/../build/linux/x64/release/bundle}"
if [[ ! -x "$BUNDLE/poulpoints" ]]; then echo "Indiquez le dossier bundle Linux compilé." >&2; exit 1; fi
command -v kpackagetool6 >/dev/null
command -v notify-send >/dev/null
command -v distrobox >/dev/null
mkdir -p "$ROOT" "$CONFIG/systemd/user"
chmod 700 "$ROOT"
cp "$HERE/helper.py" "$ROOT/helper.py"
cp "$HERE/org.poulapp.poulpoints/contents/ui/logo.png" "$ROOT/logo.png"
mkdir -p "$ROOT/app-0.8.0-attachments-fix"
cp -a "$BUNDLE/." "$ROOT/app-0.8.0-attachments-fix/"
cat > "$ROOT/launch.sh" <<'LAUNCH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/poulpoints-desktop"
exec distrobox enter poulpoints-dev -- "$ROOT/app-0.8.0-attachments-fix/poulpoints" "$@"
LAUNCH
chmod 700 "$ROOT/launch.sh"
if kpackagetool6 --type Plasma/Applet --show org.poulapp.poulpoints >/dev/null 2>&1; then
 kpackagetool6 --type Plasma/Applet --upgrade "$HERE/org.poulapp.poulpoints"
else
 kpackagetool6 --type Plasma/Applet --install "$HERE/org.poulapp.poulpoints"
fi
# systemd specifiers and quotes in the path are escaped when generating the unit.
python3 - "$ROOT" "$CONFIG/systemd/user/poulpoints-reminders.service" <<'UNIT'
import pathlib, sys
root = sys.argv[1].replace('\\', '\\\\').replace('"', '\\"').replace('%', '%%')
pathlib.Path(sys.argv[2]).write_text('[Unit]\nDescription=Rappels locaux Poulpoints\nAfter=graphical-session.target\nPartOf=graphical-session.target\n\n[Service]\nExecStart=/usr/bin/python3 "'+root+'/helper.py" watch\nRestart=on-failure\nRestartSec=15\nUMask=0077\n\n[Install]\nWantedBy=graphical-session.target\n')
UNIT
systemctl --user daemon-reload
systemctl --user enable --now poulpoints-reminders.service
printf 'Compagnon installé. Bureau KDE : Ajouter des composants graphiques → Poulpoints.\n'

# A single resident Flutter process owns storage and cloud sync for the session.
mkdir -p "$CONFIG/autostart"
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}/applications"
python3 - "$ROOT" "$CONFIG/autostart/org.poulapp.poulpoints.desktop" "${XDG_DATA_HOME:-$HOME/.local/share}/applications/org.poulapp.poulpoints.desktop" <<'AUTO'
import pathlib, sys
launch = (sys.argv[1]+"/launch.sh").replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
pathlib.Path(sys.argv[2]).write_text('[Desktop Entry]\nType=Application\nName=Poulpoints — synchronisation\nExec="'+launch+'" --background\nTerminal=false\nX-GNOME-Autostart-enabled=true\n')
pathlib.Path(sys.argv[3]).write_text('[Desktop Entry]\nType=Application\nName=Poulpoints\nExec="'+launch+'"\nIcon='+sys.argv[1]+'/logo.png\nTerminal=false\nCategories=Office;\n')
AUTO
