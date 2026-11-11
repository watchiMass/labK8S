#!/usr/bin/env bash
# Copie le repo des labs dans le home de candidate.
set -euo pipefail

SRC="/tmp/cka-practice-labs"
if [[ -f "${SRC}/cka-practice-labs/lib/common.sh" ]]; then
  SRC="${SRC}/cka-practice-labs"
fi
[[ -f "${SRC}/lib/common.sh" ]] || { echo "Labs introuvables" >&2; exit 1; }

install -d -m 0755 -o candidate -g candidate /home/candidate/cka-practice-labs
cp -a "${SRC}/." /home/candidate/cka-practice-labs/
chown -R candidate:candidate /home/candidate/cka-practice-labs
echo "Labs installés dans /home/candidate/cka-practice-labs (fichiers de travail conservés)"
