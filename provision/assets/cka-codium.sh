#!/usr/bin/env bash
# Lance VSCodium en rendu logiciel : indispensable sous Xvfb (pas de GPU),
# sinon la fenêtre Electron reste noire.
set -euo pipefail
export LIBGL_ALWAYS_SOFTWARE=1
exec codium --disable-gpu "$@"
