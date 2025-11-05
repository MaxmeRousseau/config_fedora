#!/usr/bin/env bash
set -euo pipefail

# Vérifier que le script est exécuté en root
if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "Ce script doit être exécuté avec sudo ou en tant que root. Exemple : sudo $0"
  exit 1
fi

