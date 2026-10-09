#!/usr/bin/env bash
# Vollstaendige Orchestrierung: Server starten, Inference testen, Agent testen, VRAM pruefen.
set -uo pipefail
cd /content

echo "=============================================="
echo "[1/5] llama-cpp-python + CUDA verfuegbar?"
echo "=============================================="
python3 -c "from llama_cpp import Llama; print('llama_cpp import OK')" || exit 1

echo ""
echo "=============================================="
echo "[2/5] Server starten"
echo "=============================================="
bash /content/scripts/start_server.sh || exit 1

echo ""
echo "=============================================="
echo "[3/5] Inference-Test"
echo "=============================================="
python3 /content/scripts/test_inference.py || exit 1

echo ""
echo "=============================================="
echo "[4/5] pi-coding-Agent-Test"
echo "=============================================="
mkdir -p /content/output
bash /content/scripts/test_pi.sh || exit 1

echo ""
echo "=============================================="
echo "[5/5] VRAM-Belegung (T4)"
echo "=============================================="
nvidia-smi
echo ""
echo "Alle Schritte abgeschlossen."
