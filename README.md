# Lab CKA — environnement d'entraînement type examen

Cluster Kubernetes Vagrant (1 control plane + 2 workers) avec un desktop XFCE
qui reproduit l'environnement d'examen CKA : terminal, Firefox, VSCodium,
clavier virtuel, prompt `candidate@base`, et une ExamUI locale (questions à
gauche, timer 2 h, Remote Desktop noVNC à droite).

Les exercices se trouvent dans [cka-practice-labs/](cka-practice-labs/) et sont
inchangés : chaque question a son `setup.sh`, `question.md`, `validate.sh` et
`cleanup.sh`.

## Architecture

| Rôle | VM Vagrant | Hostname / node K8s | IP | CPU / RAM / Disque |
|---|---|---|---|---|
| Control plane + desktop | `cp1` | `base` | 192.168.56.10 | 4 / 6 Go / 40 Go |
| Worker | `w1` | `node01` | 192.168.56.11 | 2 / 2 Go / 20 Go |
| Worker | `w2` | `node02` | 192.168.56.12 | 2 / 2 Go / 20 Go |

- Ubuntu 24.04, containerd, kubeadm/kubelet/kubectl, Cilium.
- Utilisateur desktop `candidate`, sudo sans mot de passe (UID attribué
  automatiquement, car l'image cloud réserve déjà 1000/1001).
- `vagrant` reste l'utilisateur de provisioning et de `vagrant ssh`.
- `candidate@base` peut faire `ssh node01` / `ssh node02` sans mot de passe
  (nécessaire pour B06 et D14).

## Démarrage

Prérequis : Vagrant + libvirt/KVM, environ 10 Go de RAM libre pour les VMs,
80 Go de disque, accès Internet depuis les VMs.

```bash
vagrant validate
vagrant up          # premier lancement : 20 à 30 minutes
```

Le premier `vagrant up` installe XFCE, Firefox, VSCodium, noVNC, Cilium et les
images Kubernetes. Les provisioners sont idempotents : `kubeadm init/join` ne
se relance pas si le cluster existe déjà.

## Accès

| Service | URL / hôte | Identifiants |
|---|---|---|
| ExamUI (principal) | <http://192.168.56.10:8080/> | — |
| noVNC direct (secours) | <http://192.168.56.10:6080/vnc.html> | mot de passe VNC `cka-lab1` |
| RDP (secours) | `192.168.56.10:3389` | `candidate` / `candidate` |
| SSH base | `bash scripts/ssh-base.sh` | clé `provision/.lab_key` |
| SSH workers | `ssh candidate@192.168.56.11` (depuis base) | clé labo |

Ouvrez l'ExamUI dans le navigateur de votre hôte (Firefox ou Chromium), pas
dans le Firefox du desktop. Les services sont sur le réseau privé libvirt,
accessible uniquement depuis l'hôte.

Mots de passe configurables avant le `vagrant up` :

```bash
export CKA_DESKTOP_PASSWORD='candidate'   # SSH/RDP
export CKA_VNC_PASSWORD='cka-lab1'       # VNC (8 caractères max)
```

`CKA_VNC_PASSWORD` est tronqué à 8 caractères, limite de l'authentification VNC.

## Le desktop d'examen

- XFCE avec wallpaper bleu, panneau supérieur (Applications, Terminal, horloge)
  et dock inférieur (Terminal, VSCodium, Firefox, Keyboard, File Manager).
- Terminal sombre ouvert au login, prompt `candidate@base:~$`.
- Firefox installé en `.deb` (pas le snap Ubuntu), page d'accueil
  `https://kubernetes.io/docs/home/`.
- VSCodium, clavier virtuel Onboard, Thunar.
- Clavier **FR AZERTY par défaut** (choix utilisateur). L'examen réel utilise
  un clavier **US QWERTY** : basculez avec `cka-keyboard us` (ou l'icône clavier
  du panneau après y avoir ajouté US), et refaites au moins une session
  chronométrée en US.
- Session XFCE dédiée sur `DISPLAY=:1` (Xvfb 1920×1080), servie par x11vnc +
  websockify. `xrdp` reste disponible en secours.

### Copier/coller

- Dans le terminal : `Ctrl+Shift+C` / `Ctrl+Shift+V`.
- Depuis l'ExamUI : les boutons « Copy to desktop » envoient le texte au
  presse-papier distant ; collez ensuite avec `Ctrl+Shift+V` dans le terminal.
- En RDP, le presse-papier fonctionne directement entre l'hôte et la session.

### Firefox

Par défaut, Firefox est limité à `kubernetes.io` (comme à l'examen). Pour
ouvrir d'autres sites pendant les labs :

```bash
sudo cka-firefox-mode open       # puis relancer Firefox
sudo cka-firefox-mode restricted # remettre le mode examen
```

Les liens Kubernetes d'une question s'ouvrent dans le Firefox du desktop via
l'ExamUI.

## Les labs

Le repo est copié dans `~/cka-practice-labs` sur `base` (inscriptible, car les
scripts écrivent dans les dossiers de questions).

Depuis le terminal du desktop :

```bash
cd ~/cka-practice-labs/series-a/q01-contexts-csr
bash setup.sh
cat question.md
bash validate.sh
bash cleanup.sh
```

L'ExamUI affiche la question et un encart « Lab helper » avec ces commandes.

Pour modifier les labs sur l'hôte et les injecter dans la VM :

```bash
bash scripts/sync-labs.sh          # met à jour sans supprimer votre travail
bash scripts/sync-labs.sh --prune  # miroir exact (supprime les fichiers en trop)
```

## SSH et nœuds

```bash
# Depuis l'hôte
bash scripts/ssh-base.sh
bash scripts/ssh-base.sh 'kubectl get nodes -o wide'

# Depuis le desktop (terminal)
ssh node01
ssh node02
sudo -n true   # sudo sans mot de passe pour les tâches node-level
```

`vagrant ssh cp1` fonctionne toujours en tant que `vagrant` ; pour passer à
l'utilisateur desktop : `sudo -iu candidate`.

## Capture du desktop

```bash
bash scripts/screenshot-desktop.sh /tmp/cka-desktop.png
```

Utile pour comparer le rendu avec les captures officielles de l'ExamUI.

## Re-provisionner sans casser le cluster

```bash
# Réinstaller les assets, le desktop, l'ExamUI et les labs depuis l'hôte
vagrant provision cp1 --provision-with desktop-assets,desktop,desktop-config,exam-console-files,exam-console,labs-files,labs

# Ou seulement une partie, par exemple la config du desktop ou l'ExamUI
vagrant provision cp1 --provision-with desktop-assets,desktop-config
vagrant provision cp1 --provision-with exam-console-files,exam-console

# Vérifier l'état
vagrant ssh cp1 -c 'kubectl get nodes -o wide'
```

Les noms de provisioners sont définis dans le [Vagrantfile](Vagrantfile). Le repo
des labs dans la VM est mis à jour plus simplement avec `bash scripts/sync-labs.sh`.

Après une modification de configuration ou de mot de passe, `systemctl enable
--now` ne redémarre pas un service déjà actif :

```bash
vagrant ssh cp1 -c 'sudo systemctl restart exam-desktop exam-vnc exam-novnc exam-console'
```

Reconstruction complète (destructive) :

```bash
vagrant destroy -f
vagrant up
```

Si vous changez `CKA_DESKTOP_PASSWORD` ou `CKA_VNC_PASSWORD` après coup,
re-provisionnez `candidate`, `desktop` et `exam-console` (le premier met à jour
le mot de passe du compte, les deux autres le mot de passe VNC).

## Dépannage

```bash
vagrant ssh cp1 -c 'systemctl status exam-xvfb exam-desktop exam-vnc exam-novnc exam-console xrdp'
vagrant ssh cp1 -c 'journalctl -u exam-desktop -u exam-console -n 100 --no-pager'
```

- **ExamUI inaccessible** : vérifier `exam-console` sur le port 8080 et le
  navigateur de l'hôte. `curl http://192.168.56.10:8080/healthz` doit répondre
  `ok`.
- **Desktop noir / pas de VNC** : vérifier `exam-xvfb`, `exam-desktop`,
  `exam-vnc` et `exam-novnc`. La session est sur `DISPLAY=:1`.
- **Firefox ne s'ouvre pas depuis un lien** : le service `exam-console` tourne
  en `candidate` avec `DISPLAY=:1` ; vérifier que Firefox est installé.
- **VSCodium affiche une fenêtre noire** : le wrapper `cka-codium` force le
  rendu logiciel (pas de GPU sous Xvfb). Relancez-le via `cka-codium` plutôt
  que `codium`.
- **VSCodium/Firefox refusent de démarrer (répertoires non accessibles)** :
  la session Xvfb utilise un répertoire d'exécution dédié `/run/cka-desktop`
  (logind supprime `/run/user/<uid>` quand une session SSH/RDP se termine).
  Lancez `bash scripts/desktop-diagnostics.sh` et collez la sortie pour
  diagnostic.
- **Le filtre Firefox gêne les labs** : `sudo cka-firefox-mode open`.
- **B06/D14 échouent sur le SSH worker** : vérifier
  `ssh node01 'sudo -n true'` depuis le terminal du desktop.
- **Le `kubeconfig` à la racine est obsolète** après un rebuild ; régénérez-le
  si vous utilisez `kubectl` depuis l'hôte :
  `vagrant ssh cp1 -c 'sudo cat /etc/kubernetes/admin.conf' > kubeconfig`.

L'ExamUI locale est une reproduction d'entraînement, pas l'interface officielle
de l'examen. Le vrai Remote Desktop utilise un clavier US et Firefox limité aux
ressources autorisées ; ce lab reproduit ces contraintes autant que possible.
