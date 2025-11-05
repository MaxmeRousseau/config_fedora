#!/usr/bin/env bash
set -euo pipefail

# Vérifier que le script est exécuté en root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo ou en tant que root. Exemple : sudo $0"
  exit 1
fi

# Installer les outils de compilation nécessaires pour eza
dnf -y install cargo rust gcc make pkgconfig openssl-devel libgit2-devel

# Installer eza depuis le dépôt GitHub
git clone https://github.com/eza-community/eza.git
cd eza
cargo install --path .

echo "eza a été installé avec succès."