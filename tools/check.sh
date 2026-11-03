#!/usr/bin/env bash
# Vérification complète : import, validation des données, lint, tests, simulation rapide.
# Échoue au moindre ERROR/WARNING Godot (zéro erreur, zéro warning).
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LOG_DIR="${TMPDIR:-/tmp}/lamaison-check"
mkdir -p "$LOG_DIR"
status=0

step() { printf '\n\033[1;33m== %s ==\033[0m\n' "$1"; }
scan() { # $1 = log ; signale erreurs/warnings Godot
  if grep -E "^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING)|Parse Error|Failed to load" "$1" >/dev/null; then
    grep -E -A2 "^(ERROR|WARNING|SCRIPT ERROR|USER ERROR|USER WARNING)|Parse Error|Failed to load" "$1" | head -60
    return 1
  fi
  return 0
}

step "Import"
"$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1
scan "$LOG_DIR/import.log" || status=1

step "Validation des données"
"$GODOT" --headless --path . -s res://tools/validate_data.gd >"$LOG_DIR/validate.log" 2>&1 || status=1
tail -5 "$LOG_DIR/validate.log"
scan "$LOG_DIR/validate.log" || status=1

step "Traductions"
python3 tools/i18n_check.py | tail -3 || status=1

step "Audio (mesures objectives)"
python3 tools/audio_report.py >"$LOG_DIR/audio.log" 2>&1 || status=1
tail -1 "$LOG_DIR/audio.log"
python3 tools/audio_mix.py --check >"$LOG_DIR/audio_mix.log" 2>&1 || status=1
tail -1 "$LOG_DIR/audio_mix.log"

step "Lint (gdlint)"
if command -v gdlint >/dev/null; then
  gdlint scripts tests tools 2>&1 | tail -20 || status=1
else
  echo "gdlint absent (uv tool install gdtoolkit)"; status=1
fi

step "Tests"
"$GODOT" --headless --path . -s res://tests/run_tests.gd >"$LOG_DIR/tests.log" 2>&1 || status=1
grep -E "ÉCHEC|Tests :" "$LOG_DIR/tests.log"
scan "$LOG_DIR/tests.log" || status=1

step "Fuzzing de graines"
"$GODOT" --headless --path . -s res://tools/fuzz.gd -- --runs=150 --seed=$RANDOM >"$LOG_DIR/fuzz.log" 2>&1 || status=1
grep -E "Fuzz|INVARIANT" "$LOG_DIR/fuzz.log"
scan "$LOG_DIR/fuzz.log" || status=1

step "Simulation rapide"
"$GODOT" --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=40 --bot=greedy --quiet >"$LOG_DIR/sim.log" 2>&1 || status=1
tail -4 "$LOG_DIR/sim.log"
scan "$LOG_DIR/sim.log" || status=1

step "Épreuves du lancer (bot parfait et joueur inactif)"
"$GODOT" --headless --path . -- --dev-trial-bench=3 >"$LOG_DIR/trials.log" 2>&1 || status=1
grep -E "^Épreuve" "$LOG_DIR/trials.log"
scan "$LOG_DIR/trials.log" || status=1

step "Interface (focus manette, chevauchements, débordements, 6 résolutions)"
"$GODOT" --headless --path . -- --dev-ui-check >"$LOG_DIR/ui.log" 2>&1 || status=1
grep -E "^UI :|Interface :" "$LOG_DIR/ui.log"
scan "$LOG_DIR/ui.log" || status=1

step "Interface mobile (6 formats de téléphone, texte ×1,35 et ×1,6, cibles tactiles)"
"$GODOT" --headless --path . -- --dev-ui-check --dev-mobile >"$LOG_DIR/ui_mobile.log" 2>&1 || status=1
grep -E "^UI :|Interface :" "$LOG_DIR/ui_mobile.log"
scan "$LOG_DIR/ui_mobile.log" || status=1

step "Confirmations à la manette (Oui / Non, depuis leur vrai parent)"
"$GODOT" --headless --path . -- --dev-confirm-check >"$LOG_DIR/confirm.log" 2>&1 || status=1
grep -E "^CONFIRM :|Confirmations :" "$LOG_DIR/confirm.log"
scan "$LOG_DIR/confirm.log" || status=1

step "Campagne complète à la manette seule (dettes réduites)"
if [ "${SKIP_PAD_RUN:-0}" = "1" ]; then echo "(ignorée : SKIP_PAD_RUN=1)"; else
rm -f "$HOME/.local/share/godot/app_userdata/La Maison Gagne/dev/run.json" "$HOME/.local/share/godot/app_userdata/La Maison Gagne/dev/run.json.bak"
"$GODOT" --headless --path . -- --dev-pad-run=500 --dev-debt-mult=0.01 >"$LOG_DIR/pad.log" 2>&1 || status=1
grep -E "Partie à la manette|traversés" "$LOG_DIR/pad.log"
scan "$LOG_DIR/pad.log" || status=1
fi

step "Démarrage du jeu (headless, 120 frames)"
"$GODOT" --headless --path . -- --quit-frames=120 >"$LOG_DIR/boot.log" 2>&1
scan "$LOG_DIR/boot.log" || status=1

if [ $status -eq 0 ]; then printf '\n\033[1;32mOK : tout est vert.\033[0m\n'; else printf '\n\033[1;31mÉCHEC : voir %s\033[0m\n' "$LOG_DIR"; fi
exit $status
