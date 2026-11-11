#!/usr/bin/env bash
# Crée l'utilisateur candidate, installe sa clé SSH de labo et prépare
# l'accès base -> node01/node02 (utilisé par B06 et D14).
set -euo pipefail

CANDIDATE_USER="candidate"

if ! id -u "${CANDIDATE_USER}" >/dev/null 2>&1; then
  # Ne pas imposer d'UID : l'image cloud utilise déjà 1000/1001 (ubuntu/vagrant).
  useradd -m -s /bin/bash "${CANDIDATE_USER}"
fi

echo "${CANDIDATE_USER}:${CKA_DESKTOP_PASSWORD}" | chpasswd
printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${CANDIDATE_USER}" > /etc/sudoers.d/90-candidate
chmod 0440 /etc/sudoers.d/90-candidate

# Noms d'hôtes utilisés par les labs et par les tâches « ssh node01 ».
for entry in \
  "192.168.56.10 base" \
  "192.168.56.11 node01" \
  "192.168.56.12 node02"; do
  hostname_part="$(awk '{print $2}' <<<"${entry}")"
  if ! grep -qE "^[0-9.]+[[:space:]]+${hostname_part}([[:space:]]|$)" /etc/hosts; then
    printf '%s\n' "${entry}" >>/etc/hosts
  fi
done

install -d -m 0700 -o "${CANDIDATE_USER}" -g "${CANDIDATE_USER}" "/home/${CANDIDATE_USER}/.ssh"

if [[ -f /tmp/cka-lab-key.pub ]]; then
  pubkey="$(cat /tmp/cka-lab-key.pub)"
  auth="/home/${CANDIDATE_USER}/.ssh/authorized_keys"
  touch "${auth}"
  grep -qF "${pubkey}" "${auth}" || printf '%s\n' "${pubkey}" >>"${auth}"
  chown "${CANDIDATE_USER}:${CANDIDATE_USER}" "${auth}"
  chmod 0600 "${auth}"
fi

if [[ -f /tmp/cka-lab-key ]]; then
  install -m 0600 -o "${CANDIDATE_USER}" -g "${CANDIDATE_USER}" \
    /tmp/cka-lab-key "/home/${CANDIDATE_USER}/.ssh/id_ed25519"
fi

cat >"/home/${CANDIDATE_USER}/.ssh/config" <<'EOF'
Host node01 node02
  User candidate
  IdentityFile ~/.ssh/id_ed25519
  StrictHostKeyChecking accept-new
EOF
chown "${CANDIDATE_USER}:${CANDIDATE_USER}" "/home/${CANDIDATE_USER}/.ssh/config"
chmod 0600 "/home/${CANDIDATE_USER}/.ssh/config"

if ! grep -q 'CKA lab environment' "/home/${CANDIDATE_USER}/.bashrc"; then
  cat >>"/home/${CANDIDATE_USER}/.bashrc" <<'EOF'

# --- CKA lab environment ---
PS1='\u@\h:\w\$ '
if command -v kubectl >/dev/null 2>&1; then
  source <(kubectl completion bash)
fi
EOF
  chown "${CANDIDATE_USER}:${CANDIDATE_USER}" "/home/${CANDIDATE_USER}/.bashrc"
fi
