#!/usr/bin/env bash
# Installe les thèmes, les lanceurs, le wallpaper et les services du desktop
# d'examen pour l'utilisateur candidate.
set -euo pipefail

ASSETS="/tmp/cka-assets"
if [[ -f "${ASSETS}/assets/cka-theme.sh" ]]; then
  ASSETS="${ASSETS}/assets"
fi
[[ -f "${ASSETS}/cka-theme.sh" ]] || { echo "Assets desktop introuvables" >&2; exit 1; }

CAND="/home/candidate"
CONF="${CAND}/.config"
XFCE="${CONF}/xfce4"
XFCONF="${XFCE}/xfconf/xfce-perchannel-xml"
PANEL="${XFCE}/panel"

# --- Scripts utilitaires ---
install -m 0755 "${ASSETS}/cka-theme.sh" /usr/local/bin/cka-theme.sh
install -m 0755 "${ASSETS}/cka-keyboard.sh" /usr/local/bin/cka-keyboard.sh
install -m 0755 "${ASSETS}/cka-firefox-mode.sh" /usr/local/bin/cka-firefox-mode.sh
install -m 0755 "${ASSETS}/cka-codium.sh" /usr/local/bin/cka-codium

# --- Wallpaper ---
install -d -m 0755 /usr/share/backgrounds
install -m 0644 "${ASSETS}/cka-wallpaper.svg" /usr/share/backgrounds/cka-exam.svg
rsvg-convert -w 1920 -h 1080 /usr/share/backgrounds/cka-exam.svg \
  -o /usr/share/backgrounds/cka-exam.png

# --- Configuration xfconf ---
install -d -m 0755 -o candidate -g candidate "${XFCONF}"
for f in xfce4-panel.xml xfce4-terminal.xml xfce4-desktop.xml xfwm4.xml xsettings.xml; do
  install -m 0644 -o candidate -g candidate "${ASSETS}/xfce/${f}" "${XFCONF}/${f}"
done

# --- Lanceurs des panneaux ---
install -d -m 0755 -o candidate -g candidate \
  "${PANEL}/launcher-2" "${PANEL}/launcher-7" "${PANEL}/launcher-10" \
  "${PANEL}/launcher-11" "${PANEL}/launcher-12" "${PANEL}/launcher-13"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/terminal.desktop" "${PANEL}/launcher-2/terminal.desktop"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/terminal.desktop" "${PANEL}/launcher-7/terminal.desktop"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/codium.desktop" "${PANEL}/launcher-10/codium.desktop"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/firefox.desktop" "${PANEL}/launcher-11/firefox.desktop"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/onboard.desktop" "${PANEL}/launcher-12/onboard.desktop"
install -m 0755 -o candidate -g candidate \
  "${ASSETS}/desktop/thunar.desktop" "${PANEL}/launcher-13/thunar.desktop"

# --- Icônes du bureau ---
install -d -m 0755 -o candidate -g candidate "${CAND}/Desktop"
for f in terminal codium firefox onboard thunar; do
  install -m 0755 -o candidate -g candidate \
    "${ASSETS}/desktop/${f}.desktop" "${CAND}/Desktop/${f}.desktop"
done

# --- Démarrage automatique ---
install -d -m 0755 -o candidate -g candidate "${CONF}/autostart"
install -m 0644 -o candidate -g candidate \
  "${ASSETS}/autostart/cka-theme.desktop" "${CONF}/autostart/cka-theme.desktop"
install -m 0644 -o candidate -g candidate \
  "${ASSETS}/autostart/terminal.desktop" "${CONF}/autostart/terminal.desktop"

# --- Session xrdp ---
cat >"${CAND}/.xsession" <<'EOF'
#!/bin/sh
setxkbmap fr
exec startxfce4
EOF
chmod 0755 "${CAND}/.xsession"
chown candidate:candidate "${CAND}/.xsession"

# --- Politiques Firefox ---
install -d -m 0755 /etc/firefox/policies /usr/local/share/cka
install -m 0644 "${ASSETS}/firefox/policies-restricted.json" \
  /usr/local/share/cka/firefox-policies-restricted.json
install -m 0644 "${ASSETS}/firefox/policies-open.json" \
  /usr/local/share/cka/firefox-policies-open.json
install -m 0644 /usr/local/share/cka/firefox-policies-restricted.json \
  /etc/firefox/policies/policies.json

# --- Services du desktop d'examen ---
CANDIDATE_UID="$(id -u candidate)"
for unit in exam-xvfb exam-desktop exam-vnc exam-novnc; do
  sed "s/@CANDIDATE_UID@/${CANDIDATE_UID}/g" "${ASSETS}/systemd/${unit}.service" \
    > "/etc/systemd/system/${unit}.service"
  chmod 0644 "/etc/systemd/system/${unit}.service"
done
# Répertoire d'exécution dédié à la session Xvfb : logind gère
# /run/user/<uid> pour les sessions SSH/RDP et le supprime quand elles se
# terminent, ce qui casse les applis du desktop. Un répertoire dédié évite
# ce conflit.
install -d -m 0700 -o candidate -g candidate /run/cka-desktop

# Corrige les propriétés laissées par d'anciens lancements en root
# (VSCodium, .vscode-oss, .mozilla).
chown -R candidate:candidate /home/candidate

systemctl daemon-reload
systemctl enable --now exam-xvfb.service
systemctl enable --now exam-desktop.service
systemctl enable --now exam-vnc.service
systemctl enable --now exam-novnc.service
systemctl enable --now xrdp.service

# Appliquer les fichiers de config aux sessions déjà lancées.
systemctl restart exam-desktop.service
systemctl restart exam-vnc.service
systemctl restart exam-novnc.service

echo "Desktop d'examen configuré."
