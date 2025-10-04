#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat <<'USAGE'
Usage: selftest-benchmark.sh [options]

Exécute des auto-tests rapides (CPU, disque, réseau) et compare à une baseline.

Variables:
  RESULT_DIR        Dossier pour stocker les résultats (défaut: /opt/reports/selftest)
  BASELINE_FILE     Fichier baseline (défaut: RESULT_DIR/baseline.txt)
  UPDATE_BASELINE   1 pour écraser la baseline avec la dernière mesure

Options:
  --dry-run        Simule
  --yes, -y        Confirme
  --verbose, -v    Verbosité
  --quiet, -q      Silencieux
  --no-color       Sans couleurs
  --help, -h       Aide
USAGE
}

parse_common_args "$@"
set -- "${COMMON_POSITIONAL_ARGS[@]:-}"

if [[ ${SHOW_HELP} -eq 1 ]]; then
  usage
  exit 0
fi

RESULT_DIR=${RESULT_DIR:-/opt/reports/selftest}
BASELINE_FILE=${BASELINE_FILE:-${RESULT_DIR}/baseline.txt}
UPDATE_BASELINE=${UPDATE_BASELINE:-0}

ensure_dir "${RESULT_DIR}"

RESULT_FILE="${RESULT_DIR}/run-$(date +%Y%m%d-%H%M%S).txt"

run_cpu_test() {
  log_info "Test CPU (openssl prime)"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "CPU_TEST=DRY_RUN" >>"${RESULT_FILE}"
    return
  fi
  local start=$(date +%s%N)
  openssl prime -generate -bits 4096 >/dev/null 2>&1
  local end=$(date +%s%N)
  local duration=$(( (end - start) / 1000000 ))
  echo "CPU_OPENSSL_MS=${duration}" >>"${RESULT_FILE}"
}

run_disk_test() {
  log_info "Test disque (fio simplifié)"
  local test_file="${RESULT_DIR}/fio-test.bin"
  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "DISK_TEST=DRY_RUN" >>"${RESULT_FILE}"
    return
  fi
  dd if=/dev/zero of="${test_file}" bs=1M count=512 oflag=dsync 2>"${RESULT_DIR}/dd-write.log" || true
  dd if="${test_file}" of=/dev/null bs=1M 2>"${RESULT_DIR}/dd-read.log" || true
  rm -f "${test_file}"
  local write_speed=$(awk '/copied/ {print $(NF-1)" "$(NF)}' "${RESULT_DIR}/dd-write.log")
  local read_speed=$(awk '/copied/ {print $(NF-1)" "$(NF)}' "${RESULT_DIR}/dd-read.log")
  echo "DISK_WRITE=${write_speed}" >>"${RESULT_FILE}"
  echo "DISK_READ=${read_speed}" >>"${RESULT_FILE}"
}

run_network_test() {
  log_info "Test réseau (ping gateway)"
  local gateway
  gateway=$(ip route show default | awk '/default/ {print $3}' | head -n1)
  if [[ -z ${gateway} ]]; then
    echo "NET_GATEWAY=UNKNOWN" >>"${RESULT_FILE}"
    return
  fi
  if [[ ${DRY_RUN} -eq 1 ]]; then
    echo "NET_PING=DRY_RUN" >>"${RESULT_FILE}"
    return
  fi
  local stats
  stats=$(ping -c5 -W2 "${gateway}" | tail -n1)
  echo "NET_GATEWAY=${gateway}" >>"${RESULT_FILE}"
  echo "NET_PING=${stats}" >>"${RESULT_FILE}"
}

compare_baseline() {
  [[ -f ${BASELINE_FILE} ]] || { log_warn "Baseline absente (${BASELINE_FILE})"; return; }
  log_info "Comparaison avec baseline"
  local diffs
  diffs=$(diff -u "${BASELINE_FILE}" "${RESULT_FILE}" || true)
  if [[ -n ${diffs} ]]; then
    log_warn "Différences détectées:\n${diffs}"
  else
    log_success "Résultats conformes à la baseline"
  fi
}

update_baseline() {
  [[ ${UPDATE_BASELINE} -eq 1 ]] || return 0
  if [[ ${DRY_RUN} -eq 1 ]]; then
    log_info "[DRY-RUN] cp ${RESULT_FILE} ${BASELINE_FILE}"
    return
  fi
  cp "${RESULT_FILE}" "${BASELINE_FILE}"
  log_success "Baseline mise à jour"
}

main() {
  run_cpu_test
  run_disk_test
  run_network_test
  compare_baseline
  update_baseline
  log_success "Self-test terminé (${RESULT_FILE})"
}

main "$@"
