#!/usr/bin/env bash
# Testet den pi-coding-agent gegen den lokalen llama.cpp-Server.
set -euo pipefail

cd /content

# Sicherstellen, dass der Server laeuft
bash /content/scripts/start_server.sh

echo "[pi] Verfuegbare Modelle:"
pi --provider llama-cpp --list-models 2>&1 | head -20 || true

echo ""
echo "[pi] Fuehre Agent-Aufgabe aus (Non-Interactive-Modus)..."
echo "======================================================"
pi \
  --provider llama-cpp \
  --model qwen3.5-4B-super-coder.Q4_0 \
  --no-session \
  -p "Schreibe eine Python-Funktion fuer Binary Search in die Datei /content/output/binary_search.py. Danach kurz bestaetigen."
echo "======================================================"
echo "[pi] Agent-Lauf abgeschlossen."
