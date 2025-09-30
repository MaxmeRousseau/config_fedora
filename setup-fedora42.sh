#!/usr/bin/env bash
set -euo pipefail

# Script d'installation pour Fedora 42
# - Vérifie execution en root/sudo
# - Met à jour tous les paquets
# - Installe : Visual Studio Code, GNOME Tweaks, GNOME Extensions Manager, ghostty
# Usage: sudo ./setup-fedora42.sh

# Fichier de log (enregistrer uniquement SUCCESS/ERROR par étape)
# Par défaut on ajoute un horodatage pour créer des fichiers de log uniques par exécution
TIMESTAMP=$(date +'%F_%H%M%S')
LOG=${LOG:-/var/log/setup-fedora42_${TIMESTAMP}.log}

# Vérifier que le script est exécuté en root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo ou en tant que root. Exemple : sudo $0"
  exit 1
fi

# S'assurer que le fichier de log existe
mkdir -p "$(dirname "$LOG")"
touch "$LOG"

# Fonction utilitaire pour exécuter une commande en tant que chaîne et logguer SUCCESS/ERROR
# Usage: step_cmd "Description" "command as a string"
step_cmd() {
  local desc="$1"
  shift
  local cmd="$*"
  echo "--- $desc ---"
  # désactiver set -e temporairement pour gérer le code de retour nous-mêmes
  set +e
  bash -c "$cmd" >/dev/null 2>&1
  local rc=$?
  set -e
  if [ $rc -eq 0 ]; then
    echo "$(date +'%F %T') - $desc - SUCCESS" >> "$LOG"
  else
    echo "$(date +'%F %T') - $desc - ERROR (exit $rc)" >> "$LOG"
  fi
  return $rc
}

echo "--- Début du script; les résultats (SUCCESS/ERROR) seront écrits dans $LOG ---"

step_cmd "Mise à jour des paquets (dnf upgrade)" "dnf -y upgrade --refresh"

# Déterminer l'utilisateur cible pour installer nvm (préférer SUDO_USER)
TARGET_USER=${SUDO_USER:-root}
TARGET_HOME=$(eval echo "~$TARGET_USER")

step_cmd "Installation curl (prérequis pour nvm)" "dnf -y install curl"

# Installer NVM pour l'utilisateur cible (le script d'installation ajoute les lignes dans ~/.profile ou ~/.bashrc)
step_cmd "Installation NVM pour $TARGET_USER" "sudo -u \"$TARGET_USER\" -H bash -lc \"export HOME=\\\"$TARGET_HOME\\\"; curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash\""

step_cmd "Installation GNOME Tweaks et GNOME Extensions" "dnf -y install gnome-tweaks gnome-extensions-app gnome-extensions"

step_cmd "Import clé Microsoft pour VS Code" "rpm --import https://packages.microsoft.com/keys/microsoft.asc"

# Création du repo VS Code via heredoc (exécuté comme une commande bash)
step_cmd "Création du repo VS Code (/etc/yum.repos.d/vscode.repo)" "echo -e \"[code]\\nname=Visual Studio Code\\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\\nenabled=1\\nautorefresh=1\\ntype=rpm-md\\ngpgcheck=1\\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\" | tee /etc/yum.repos.d/vscode.repo > /dev/null"

step_cmd "Mettre à jour la liste des paquets (check-update)" "dnf -y check-update || true"

step_cmd "Installation Visual Studio Code (code)" "dnf -y install code"

## Installation idempotente de ghostty
# Si le binaire est déjà présent, on skip
if command -v ghostty >/dev/null 2>&1; then
  echo "ghostty déjà présent, saut de l'installation"
  echo "$(date +'%F %T') - Installation ghostty - SKIP (already installed)" >> "$LOG"
else
  # Assurer le support des plugins DNF (copr)
  step_cmd "Installer dnf-plugins-core (pour copr)" "dnf -y install dnf-plugins-core" || true

  # Activer le COPR contenant ghostty (scottames/ghostty) puis tenter l'installation via dnf
  step_cmd "Activer COPR scottames/ghostty" "dnf -y copr enable scottames/ghostty" || true
  step_cmd "Installation de ghostty via dnf (copr scottames/ghostty)" "dnf -y install ghostty" || true

  # Si l'installation via dnf n'a pas créé le binaire, fallback sur npm
  if command -v ghostty >/dev/null 2>&1; then
    echo "ghostty installé via dnf/COPR"
    echo "$(date +'%F %T') - Installation ghostty via dnf - SUCCESS" >> "$LOG"
  else
    echo "ghostty non installé via dnf — tentative via npm/Node.js"
    # Installer nodejs si nécessaire
    if ! command -v node >/dev/null 2>&1; then
      step_cmd "Installation Node.js (nodejs)" "dnf -y install nodejs"
    else
      echo "Node.js présent — pas d'installation nécessaire"
    fi

    if command -v npm >/dev/null 2>&1; then
      step_cmd "Installation ghostty via npm (npm install -g ghostty)" "npm install -g ghostty"
    else
      echo "npm indisponible : impossible d'installer ghostty automatiquement. Voir https://github.com/ghostty/ghostty"
      echo "$(date +'%F %T') - Installation ghostty via npm - ERROR (npm absent)" >> "$LOG"
    fi
  fi
fi

step_cmd "Nettoyage (dnf autoremove)" "dnf -y autoremove"

cat <<EOF
Terminé.
Les résultats SUCCESS/ERROR de chaque étape ont été écrits dans : $LOG
EOF
