#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'EOF'
Usage: 00-preflight-checks.sh [options]

Vérifie l'état du Raspberry Pi 5 avant l'installation d'un stack.

Options:
  --dry-run        Simule les actions sans exécuter les commandes
  --yes, -y        Accepte toutes les confirmations
  --verbose, -v    Niveau de verbosité supplémentaire (cumulable)
  --quiet, -q      Mode silencieux (logs essentiels uniquement)
  --no-color       Désactive les couleurs dans la sortie
  --help, -h       Affiche cette aide
EOF
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

PASS_CHECKS=()
WARN_CHECKS=()
FAIL_CHECKS=()

mark_pass() { PASS_CHECKS+=("$1"); log_success "$1"; }
mark_warn() { WARN_CHECKS+=("$1"); log_warn "$1"; }
mark_fail() { FAIL_CHECKS+=("$1"); log_error "$1"; }

section() {
  log_info "=============================="
  log_info "$1"
  log_info "=============================="
}

section "Informations système"

OS_NAME=$(detect_pretty_os)
ARCH=$(detect_arch)
KERNEL=$(uname -r)
HOSTNAME=$(hostname)

log_info "Hôte : ${HOSTNAME}"
log_info "OS   : ${OS_NAME:-inconnu}"
log_info "Arch : ${ARCH}"
log_info "Kernel : ${KERNEL}"

if [[ ${ARCH} != "aarch64" ]]; then
  mark_warn "Architecture ${ARCH} détectée (attendu: aarch64)"
else
  mark_pass "Architecture ARM64 détectée"
fi

if [[ ${OS_NAME} =~ (Raspberry|Debian|Ubuntu) ]]; then
  mark_pass "OS compatible (${OS_NAME})"
else
  mark_warn "OS non identifié (${OS_NAME}). Vérifiez la compatibilité."
fi

section "Kernel Page Size"

PAGE_SIZE=$(getconf PAGESIZE || echo "")
if [[ -z ${PAGE_SIZE} ]]; then
  mark_fail "Impossible de déterminer la page size (getconf indisponible)"
elif [[ ${PAGE_SIZE} -eq 4096 ]]; then
  mark_pass "Page size = 4096 ✅"
else
  mark_fail "Page size actuelle ${PAGE_SIZE} (attendu: 4096). Vérifiez le correctif 16KB → 4KB."
fi

section "Ressources"

MEM_TOTAL=$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)
if (( MEM_TOTAL >= 7800000 )); then
  mark_pass "Mémoire totale >= 8GB (${MEM_TOTAL} kB)"
elif (( MEM_TOTAL >= 3900000 )); then
  mark_warn "Mémoire totale (${MEM_TOTAL} kB). Pour Supabase, 8GB recommandés."
else
  mark_fail "Mémoire insuffisante (${MEM_TOTAL} kB)"
fi

ROOT_USAGE=$(df --output=pcent / 2>/dev/null | tail -n1 | tr -dc '0-9')
if [[ -z ${ROOT_USAGE} ]]; then
  mark_warn "Impossible de lire l'utilisation disque de /."
elif (( ROOT_USAGE < 80 )); then
  mark_pass "Espace disque suffisant (usage / = ${ROOT_USAGE}%)"
else
  mark_warn "Espace disque critique (usage / = ${ROOT_USAGE}%). Libérez de l'espace."
fi

section "Réseau"

DEFAULT_ROUTE=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
if [[ -n ${DEFAULT_ROUTE} ]]; then
  mark_pass "Passerelle par défaut détectée (${DEFAULT_ROUTE})"
else
  mark_warn "Aucune passerelle par défaut détectée. Vérifiez la configuration réseau."
fi

PING_TARGET=${PING_TARGET:-1.1.1.1}
if ping -c1 -W3 "${PING_TARGET}" >/dev/null 2>&1; then
  mark_pass "Sortie Internet OK (${PING_TARGET})"
else
  mark_warn "Échec ping ${PING_TARGET}. Vérifiez la connectivité."
fi

section "Services clés"

if command -v docker >/dev/null 2>&1; then
  mark_pass "Docker installé ($(docker --version 2>/dev/null))"
else
  mark_warn "Docker non détecté. Il sera installé durant les scripts."
fi

if systemctl is-active --quiet docker 2>/dev/null; then
  mark_pass "Service Docker actif"
else
  mark_warn "Service Docker inactif"
fi

if systemctl is-active --quiet ufw 2>/dev/null; then
  mark_pass "Firewall UFW actif"
else
  log_info "UFW non actif (optionnel mais recommandé)."
fi

if timedatectl show -p NTPSynchronized 2>/dev/null | grep -q '=yes'; then
  mark_pass "Horloge synchronisée (NTP)"
else
  mark_warn "Horloge non synchronisée. Activez `systemctl enable --now systemd-timesyncd`."
fi

section "cgroups & containers"

if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
  mark_pass "cgroup v2 détecté"
else
  mark_warn "cgroup v2 non détecté. Vérifiez la configuration du kernel."
fi

if systemd-detect-virt >/dev/null 2>&1; then
  VIRT_TYPE=$(systemd-detect-virt)
  if [[ ${VIRT_TYPE} == "none" ]]; then
    mark_pass "Aucune virtualisation détectée (bare metal)"
  else
    mark_warn "Exécution dans un environnement virtualisé (${VIRT_TYPE}). Performances à valider."
  fi
fi

section "Résumé"

TOTAL=$(( ${#PASS_CHECKS[@]} + ${#WARN_CHECKS[@]} + ${#FAIL_CHECKS[@]} ))
log_info "Checks exécutés : ${TOTAL}"
log_success "Réussites : ${#PASS_CHECKS[@]}"
if [[ ${#WARN_CHECKS[@]} -gt 0 ]]; then
  log_warn "Avertissements : ${#WARN_CHECKS[@]}"
fi
if [[ ${#FAIL_CHECKS[@]} -gt 0 ]]; then
  log_error "Échecs : ${#FAIL_CHECKS[@]}"
fi

if [[ ${#FAIL_CHECKS[@]} -gt 0 ]]; then
  log_error "Corrigez les échecs avant de poursuivre l'installation."
  exit 1
fi

log_success "Préflight terminé. Vous pouvez poursuivre l'installation."
