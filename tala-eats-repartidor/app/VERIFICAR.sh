#!/usr/bin/env bash
# Tala Eats Repartidor v1.2.2 - verificacion local (macOS / Linux).
set -u
cd "$(dirname "$0")" || exit 1
LOG="QA-RESULTADOS-LOCAL.txt"
FAILED=0
{
  echo "TALA EATS REPARTIDOR v1.2.2 - RESULTADOS QA LOCALES"
  echo "Fecha: $(date)"
  flutter --version
} > "$LOG" 2>&1

step() {
  local label="$1"
  shift
  local title="$*"
  echo "[$label] $title"
  { echo; echo "===== $title ====="; } >> "$LOG"
  if "$@" >> "$LOG" 2>&1; then
    echo "       OK"
  else
    echo "       FALLO"
    FAILED=1
  fi
}

step "1/9" dart format .
step "2/9" flutter pub get
step "3/9" flutter analyze
step "4/9" flutter test test/proof_flow_responsive_test.dart --reporter expanded
step "5/9" flutter test test/layout_and_motion_test.dart --reporter expanded
step "6/9" flutter test test/delivery_flow_widget_test.dart --reporter expanded
step "7/9" flutter test test/registration_flow_widget_test.dart --reporter expanded
step "8/9" flutter test test/branding_asset_test.dart --reporter expanded
step "9/9" flutter test --reporter expanded

if [ "$FAILED" -eq 0 ]; then
  echo "[OK] Todo paso. Ver $LOG"
else
  echo "[ATENCION] Hubo fallos. Ver $LOG"
fi
exit "$FAILED"
