#!/usr/bin/env bash
# Applique le thème du desktop d'examen à la session XFCE.
set -u

export DISPLAY="${DISPLAY:-:1}"

setxkbmap fr 2>/dev/null || true
xset s off -dpms 2>/dev/null || true

# xfconf-query -s échoue si la propriété n'existe pas encore : -n la crée.
set_prop() {
  local channel="$1" prop="$2" type="$3" value="$4"
  xfconf-query -c "$channel" -p "$prop" -s "$value" 2>/dev/null || \
    xfconf-query -c "$channel" -p "$prop" -n -t "$type" -s "$value" 2>/dev/null || true
}

# xfdesktop crée ses propriétés au démarrage : attendre le canal.
for _ in $(seq 1 30); do
  if xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -q '/desktop-icons/style'; then
    break
  fi
  sleep 1
done

set_prop xfce4-desktop /desktop-icons/style int 1

# Wallpaper sur tous les backdrops existants ; sinon créer le monitor0 classique.
last_images="$(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep '/last-image$' || true)"
if [[ -n "$last_images" ]]; then
  while IFS= read -r prop; do
    [[ -n "$prop" ]] || continue
    set_prop xfce4-desktop "$prop" string /usr/share/backgrounds/cka-exam.png
    set_prop xfce4-desktop "${prop%/last-image}/image-style" int 5
  done <<<"$last_images"
else
  for monitor in monitor0 monitor1 default; do
    set_prop xfce4-desktop "/backdrop/screen0/${monitor}/workspace0/last-image" \
      string /usr/share/backgrounds/cka-exam.png
    set_prop xfce4-desktop "/backdrop/screen0/${monitor}/workspace0/image-style" \
      int 5
  done
fi

# Pas de mise en veille / écran noir.
set_prop xfce4-power-manager /xfce4-power-manager/dpms-enabled bool false
set_prop xfce4-power-manager /xfce4-power-manager/blank-on-ac int 0
set_prop xfce4-power-manager /xfce4-power-manager/inactivity-on-ac int 0

# Icônes du bureau visibles et lanceurs de confiance.
for f in "$HOME"/Desktop/*.desktop; do
  [[ -e "$f" ]] || continue
  chmod +x "$f" 2>/dev/null || true
  gio set "$f" metadata::trusted true 2>/dev/null || true
done

xfdesktop --reload 2>/dev/null || true
