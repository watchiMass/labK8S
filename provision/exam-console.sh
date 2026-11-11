#!/usr/bin/env bash
# Installe l'ExamUI locale (panneau de questions + timer + noVNC) sur le port 8080.
set -euo pipefail

SRC="/tmp/cka-exam-console"
if [[ -f "${SRC}/exam-console/app.py" ]]; then
  SRC="${SRC}/exam-console"
fi
[[ -f "${SRC}/app.py" ]] || { echo "Fichiers ExamUI introuvables" >&2; exit 1; }

rm -rf /opt/cka-exam-console
install -d -m 0755 /opt/cka-exam-console
cp -a "${SRC}/." /opt/cka-exam-console/

# Le viewer custom importe noVNC depuis /vendor/novnc/.
install -d -m 0755 /opt/cka-exam-console/vendor/novnc
cp -a /usr/share/novnc/. /opt/cka-exam-console/vendor/novnc/

cat >/etc/systemd/system/exam-console.service <<EOF
[Unit]
Description=CKA exam console
After=network.target exam-desktop.service

[Service]
User=candidate
Group=candidate
Environment=DISPLAY=:1
Environment=HOME=/home/candidate
Environment=USER=candidate
Environment=LOGNAME=candidate
Environment=XDG_RUNTIME_DIR=/run/cka-desktop
Environment=XDG_SESSION_TYPE=x11
Environment=CKA_VNC_PASSWORD=${CKA_VNC_PASSWORD}
Environment=CKA_VNC_WS_PORT=6080
ExecStart=/usr/bin/python3 /opt/cka-exam-console/app.py --host 0.0.0.0 --port 8080 --labs /home/candidate/cka-practice-labs
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

chown -R candidate:candidate /opt/cka-exam-console
systemctl daemon-reload
systemctl enable --now exam-console.service
systemctl restart exam-console.service
