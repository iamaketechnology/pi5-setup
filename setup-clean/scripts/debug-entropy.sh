#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "\033[1;36m[DEBUG]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
ok() { echo -e "\033[1;32m[OK]\033[0m $*"; }

log "🔍 Diagnostic entropie Pi 5..."

echo ""
log "📊 État actuel entropie:"
cat /proc/sys/kernel/random/entropy_avail

echo ""
log "🎲 Services RNG:"
systemctl status haveged --no-pager --lines=3 || true
echo ""
systemctl status rng-tools-debian --no-pager --lines=3 || true

echo ""
log "🔧 Processus haveged:"
ps aux | grep haveged | grep -v grep || log "   Aucun processus haveged"

echo ""
log "📋 Devices RNG disponibles:"
ls -la /dev/random /dev/urandom /dev/hwrng || true

echo ""
log "🔄 Force restart services entropie..."
sudo systemctl restart haveged || true
sudo /etc/init.d/rng-tools-debian restart || true
sleep 3

echo ""
log "📊 Entropie après restart:"
cat /proc/sys/kernel/random/entropy_avail

echo ""
log "🎯 Test generation entropy..."
dd if=/dev/random of=/dev/null bs=1 count=10 iflag=nonblock 2>/dev/null && ok "✅ /dev/random OK" || warn "❌ /dev/random bloqué"

echo ""
log "🔍 Configuration rng-tools:"
cat /etc/default/rng-tools-debian 2>/dev/null || warn "Pas de config rng-tools"

echo ""
log "⚡ Test force entropie par writing..."
echo "test entropy generation" | sudo tee /dev/random >/dev/null 2>&1 || true
sleep 1
log "📊 Entropie après injection:"
cat /proc/sys/kernel/random/entropy_avail

ok "✅ Diagnostic terminé"