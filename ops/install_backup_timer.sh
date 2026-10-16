#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
config="$HOME/.config/poulpoints-backup/config.json"
# Prove a real backup and restore succeed before enabling unattended work.
distrobox enter poulpoints-dev -- python3 "$root/ops/backup_cloud.py" --config "$config"
latest=$(python3 - "$config" <<'PY'
import json,pathlib,sys
c=json.load(open(sys.argv[1]));print(max(pathlib.Path(c['destination']).glob('Poulpoints-cloud-*.tar.gpg'),key=lambda p:p.stat().st_mtime))
PY
)
distrobox enter poulpoints-dev -- python3 "$root/ops/verify_cloud_backup.py" "$latest" --passphrase-file "$HOME/.config/poulpoints-backup/encryption-password.txt"
mkdir -p "$HOME/.config/systemd/user"
python3 - "$root" "$config" "$HOME/.config/systemd/user" <<'PY'
import pathlib,sys
root,config,dest=sys.argv[1:]
def quote(s):return '"'+s.replace('\\','\\\\').replace('"','\\"').replace('%','%%')+'"'
p=pathlib.Path(dest)
(p/'poulpoints-cloud-alert.service').write_text('[Unit]\nDescription=Alerte sauvegarde Poulpoints\n\n[Service]\nType=oneshot\nExecStart=/usr/bin/notify-send --app-name=Poulpoints --urgency=critical "Sauvegarde cloud Poulpoints" "Une sauvegarde ou un contrôle a échoué. Consultez le journal des services Poulpoints."\n')
for name,script in [('backup','backup_cloud.py'),('health','check_health.py')]:
 (p/f'poulpoints-cloud-{name}.service').write_text('[Unit]\nDescription=Poulpoints cloud '+name+'\nOnFailure=poulpoints-cloud-alert.service\n\n[Service]\nType=oneshot\nUMask=0077\nExecStart=/usr/bin/distrobox enter poulpoints-dev -- python3 '+quote(root+'/ops/'+script)+' --config '+quote(config)+'\n')
 schedule='daily' if name=='backup' else 'hourly'
 (p/f'poulpoints-cloud-{name}.timer').write_text('[Unit]\nDescription=Poulpoints cloud '+name+' schedule\n\n[Timer]\nOnCalendar='+schedule+'\nPersistent=true\nRandomizedDelaySec=300\n\n[Install]\nWantedBy=timers.target\n')
PY
systemctl --user daemon-reload
systemctl --user enable --now poulpoints-cloud-backup.timer poulpoints-cloud-health.timer
