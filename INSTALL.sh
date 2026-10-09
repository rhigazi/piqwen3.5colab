#!/usr/bin/env bash
# =============================================================================
# INSTALL.sh — Komplett-Installation aus dem pi-qwen-setup-Paket
#
# Ziel: frische Google-Colab-Runtime mit T4 (16 GB VRAM) + CUDA-Toolkit
#
# Nutzung in Colab (Paket zuerst nach /content entpackt):
#   !bash /content/pi-qwen-setup/INSTALL.sh
#
# Schritte:
#   1. GPU pruefen
#   2. llama-cpp-python MIT CUDA aus dem vorgefertigten Wheel installieren
#      (~3 Sekunden — KEIN Kompilieren mehr noetig!)
#   3. Server-Extras installieren (reine Python-Pakete)
#   4. CUDA-Support verifizieren (libggml-cuda.so)
#   5. pi-Provider-Konfiguration schreiben (~/.pi/agent/models.json)
#   6. Modell laden, falls nicht vorhanden (2.6 GB, ~2 Min.)
#   7. OpenAI-kompatiblen Server starten + /v1/models + VRAM + Inference-Test
#
# Das Modell (qwen3.5-4B-super-coder.Q4_0.gguf) ist NICHT im Paket —
# es wird bei Bedarf automatisch von Hugging Face geladen.
# =============================================================================
set -euo pipefail
export PYTHONUNBUFFERED=1

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT=8000
MODEL_GGUF=qwen3.5-4B-super-coder.Q4_0.gguf
MODEL=/content/models/$MODEL_GGUF
SP=/usr/local/lib/python3.13/dist-packages

mkdir -p /content/logs /content/output

echo "================================================================"
echo " pi-qwen-setup INSTALLATION: $(date)"
echo "================================================================"

echo ""
echo "▶ Schritt 1/7: GPU pruefen"
nvidia-smi || { echo "❌ Keine GPU gefunden — T4-Runtime erforderlich!"; exit 1; }

echo ""
echo "▶ Schritt 2/7: llama-cpp-python (CUDA) aus Wheel installieren (~3 s)"
WHEEL="$(ls "$DIR"/wheels/llama_cpp_python-*.whl 2>/dev/null | head -1)"
[ -n "$WHEEL" ] || { echo "❌ Wheel fehlt in $DIR/wheels/"; exit 1; }
echo "    Wheel: $WHEEL"
pip install --no-deps --force-reinstall "$WHEEL"

echo ""
echo "▶ Schritt 3/7: Server-Extras (NUR Fertig-Wheels, --only-binary = kein Kompilieren)"
echo "    sse-starlette, starlette-context, pydantic-settings, PyYAML,"
echo "    numpy<2.3, diskcache (Laufzeit-Dep!), typing-extensions,"
echo "    huggingface_hub, fastapi, uvicorn"
pip install -q --only-binary :all: sse-starlette \
  'starlette-context>=0.3.6,<0.4' pydantic-settings PyYAML \
  'numpy<2.3' diskcache typing-extensions huggingface_hub fastapi uvicorn \
  || { echo "❌ Extras konnten nicht als Wheels installiert werden"; exit 1; }

echo ""
echo "▶ Schritt 4/7: CUDA-Support verifizieren"
if ls "$SP"/llama_cpp/lib/ | grep -q cuda; then
  echo "    ✅ CUDA-Bibliotheken vorhanden:"
  ls "$SP"/llama_cpp/lib/ | grep cuda | sed 's/^/       /'
else
  echo "❌ libggml-cuda.so fehlt — Wheel ist defekt oder Environment inkompatibel"
  exit 1
fi

echo ""
echo "▶ Schritt 5/7: pi-Konfiguration schreiben"
command -v pi >/dev/null 2>&1 || npm install -g @earendil-works/pi-coding-agent
python3 "$DIR/scripts/write_pi_config.py"

echo ""
echo "▶ Schritt 6/7: Modell sicherstellen (2.6 GB, ~2 Min., nur falls fehlend)"
if [ ! -f "$MODEL" ]; then
  mkdir -p /content/models
  python3 -c "from huggingface_hub import hf_hub_download; \
              hf_hub_download(repo_id='jica98/qwen3.5-4B-super-coder', \
                              filename='$MODEL_GGUF', local_dir='/content/models')"
fi
[ -f "$MODEL" ] || { echo "❌ Modell nicht verfügbar"; exit 1; }
echo "    ✅ Modell vorhanden: $MODEL"

echo ""
echo "▶ Schritt 7/7: OpenAI-kompatiblen Server starten (n_gpu_layers=-1)"
if curl -sf "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
  echo "    Server laeuft bereits auf Port ${PORT}"
else
  setsid nohup python3 -m llama_cpp.server \
    --model "$MODEL" \
    --n_gpu_layers -1 \
    --n_ctx 8192 \
    --host 0.0.0.0 --port "$PORT" \
    > /content/logs/llama_server.log 2>&1 < /dev/null &
  echo $! > /content/logs/llama_server.pid
  echo "    Server-PID: $(cat /content/logs/llama_server.pid)"
fi

READY=0
for i in $(seq 1 120); do
  if curl -sf "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
    echo "    ✅ Server bereit nach ~${i}s"
    READY=1
    break
  fi
  sleep 1
done
[ "$READY" = "1" ] || { echo "❌ Server wurde nicht bereit. Log:"; tail -30 /content/logs/llama_server.log; exit 1; }

echo "    /v1/models: $(curl -s "http://localhost:${PORT}/v1/models")"
echo "    VRAM-Belegung: $(nvidia-smi --query-gpu=memory.used --format=csv,noheader)"

echo ""
echo "▶ Inference-Test (tok/s)"
python3 "$DIR/scripts/test_inference.py" || echo "⚠️  Inference-Test fehlgeschlagen (Server trotzdem erreichbar?)"

echo ""
echo "================================================================"
echo " ✅ INSTALLATION FERTIG"
echo "    Server:  http://localhost:8000/v1  (OpenAI-kompatibel)"
echo "    Modell:  qwen3.5-4B-super-coder.Q4_0 (Q4_0, komplett im VRAM)"
echo "    Agent:   pi --provider llama-cpp --model qwen3.5-4B-super-coder.Q4_0"
echo "================================================================"
echo ""
echo "⚠️  HINWEIS: Der llama-cpp-python-Server (0.3.36) kann Tool-Calls NICHT"
echo "    parsen (kein tool-call-parser). Chat/Completions funktionieren,"
echo "    aber pi-Agent-Aufgaben mit Datei-Schreiben nicht. Siehe README.txt."
