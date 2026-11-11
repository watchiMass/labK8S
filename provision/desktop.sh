#!/usr/bin/env bash
# Installe la pile desktop XFCE, Firefox, VSCodium et les serveurs d'accès
# distant (noVNC + xrdp).
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y \
  xfce4 xfce4-goodies xfce4-terminal thunar xfce4-screenshooter xfce4-xkb-plugin \
  onboard xrdp xorgxrdp xauth dbus-x11 dbus-user-session \
  xvfb x11vnc novnc websockify \
  python3-markdown librsvg2-bin x11-xserver-utils x11-utils libglib2.0-bin \
  greybird-gtk-theme adwaita-icon-theme fonts-dejavu-core

# --- Firefox en .deb (le snap Ubuntu ne lit pas policies.json) ---
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
  -o /etc/apt/keyrings/packages.mozilla.org.asc
cat >/etc/apt/sources.list.d/mozilla.list <<'EOF'
deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main
EOF
cat >/etc/apt/preferences.d/mozilla <<'EOF'
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF
apt-get update
apt-get install -y firefox

# --- VSCodium ---
curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/-/raw/master/pub.gpg \
  | gpg --dearmor --yes -o /usr/share/keyrings/vscodium-archive-keyring.gpg
cat >/etc/apt/sources.list.d/vscodium.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main
EOF
apt-get update
apt-get install -y codium

# --- Mot de passe VNC (8 caractères max) ---
x11vnc -storepasswd "${CKA_VNC_PASSWORD}" /etc/x11vnc.pass >/dev/null
chmod 0600 /etc/x11vnc.pass

# --- Pas de veille ni de verrouillage ---
systemctl disable --now light-locker 2>/dev/null || true
systemctl mask light-locker 2>/dev/null || true
systemctl disable --now xscreensaver 2>/dev/null || true

systemctl enable --now xrdp
