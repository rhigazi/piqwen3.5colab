#!/usr/bin/env bash
# =============================================================================
# run_pipeline.sh — Gesamtablauf in EINEM Durchgang (eine Colab-Zelle)
#
# Ausführung in Colab:
#   !bash /content/scripts/run_pipeline.sh
#
# - Hält die VM am Leben (Zelle bleibt aktiv während des CUDA-Builds)
# - Protokolliert ALLE Ausgaben nach /content/logs/run.log
# - Bricht beim ersten Fehler ab und zeigt die letzten 40 Log-Zeilen
# - Idempotent: erledigte Schritte (CUDA-Build, laufender Server) werden
#   übersprungen, kann also bedenkenlos erneut gestartet werden
# =============================================================================
set -u
export PYTHONUNBUFFERED=1

LOG_DIR=/content/logs
LOG="$LOG_DIR/run.log"
SERVER_LOG="$LOG_DIR/llama_server.log"
MODEL_GGUF=qwen3.5-4B-super-coder.Q4_0.gguf
MODEL=/content/models/$MODEL_GGUF
PORT=8000

mkdir -p "$LOG_DIR" /content/output

# Modell sicherstellen: lokal vorhanden? sonst neu laden (~2 Min.)
if [ ! -f "$MODEL" ]; then
  echo "Modell wird heruntergeladen (2.6 GB, ~2 Min.) ..."
  mkdir -p /content/models
  python3 -c "from huggingface_hub import hf_hub_download; \
              hf_hub_download(repo_id='jica98/qwen3.5-4B-super-coder', \
                              filename='$MODEL_GGUF', local_dir='/content/models')"
fi
[ -f "$MODEL" ] || fail "Modell $MODEL nicht verfügbar"

# Alles gleichzeitig in Terminal und Log schreiben
exec > >(tee -a "$LOG") 2>&1

STEP=0
fail() {
  echo ""
  echo "############################################################"
  echo "❌ ABBRUCH in Schritt $STEP: $1"
  echo "📄 Vollständiges Log: $LOG"
  echo ">>> Die letzten 40 Zeilen zur Analyse:"
  echo "############################################################"
  tail -40 "$LOG"
  exit 1
}
step() {
  STEP=$1
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "▶ SCHITT $STEP: $2"
  echo "════════════════════════════════════════════════════════"
}

echo "================================================================"
echo " PIPELINE-START: $(date)"
echo " Log: $LOG"
echo "================================================================"

step 1 "GPU prüfen"
nvidia-smi || fail "nvidia-smi fehlgeschlagen (keine GPU?)"

step 2 "llama-cpp-python installieren (Wheel-Cache oder CUDA-Build)"
CUDA_LIB=/usr/local/lib/python3.13/dist-packages/llama_cpp/lib/libggml-cuda.so
WHEEL=""
# 1) Lokales Wheel?  2) Wheel auf Drive?  → Installation in ~3 Sek.
for W in /content/wheels/llama_cpp_python-*.whl \
         "/content/drive/MyDrive/pi-qwen-setup/wheels"/llama_cpp_python-*.whl; do
  [ -f "$W" ] && WHEEL="$W" && break
done
if [ -f "$CUDA_LIB" ]; then
  echo "libggml-cuda.so bereits vorhanden — Installation übersprungen"
elif [ -n "$WHEEL" ]; then
  echo "⚡ Installiere vorgefertigtes CUDA-Wheel (kein Kompilieren!): $WHEEL"
  pip install --no-deps --force-reinstall "$WHEEL" || fail "Wheel-Installation fehlgeschlagen"
else
  echo "Kein Wheel-Cache gefunden — Starte Source-Build mit GGML_CUDA=on (~45-90 Min auf 2 vCPU) ..."
  CMAKE_ARGS="-DGGML_CUDA=on" pip install llama-cpp-python \
    --no-binary llama-cpp-python \
    --force-reinstall --upgrade --no-cache-dir \
    || fail "CUDA-Build fehlgeschlagen"
  # Wheel für die Zukunft sichern (nach Drive kopieren, falls gemountet)
  echo "Erstelle Wheel-Artefakt aus der Installation fuer Drive-Backup ..."
  mkdir -p /content/wheels /tmp/wheelpack
  rm -rf /tmp/wheelpack/*
  SP=/usr/local/lib/python3.13/dist-packages
  cp -r "$SP/llama_cpp" "$SP"/llama_cpp_python-*.dist-info /tmp/wheelpack/
  python3 -m wheel pack /tmp/wheelpack -d /content/wheels || true
fi
# Server-Extras (nur reine Python-Pakete/Wheels — KEIN Kompilieren!)
# + diskcache (Laufzeit-Dep von llama_cpp, auf frischen Instanzen fehlend)
pip install -q --only-binary :all: sse-starlette \
  'starlette-context>=0.3.6,<0.4' pydantic-settings PyYAML \
  'numpy<2.3' diskcache typing-extensions huggingface_hub fastapi uvicorn \
  || echo "⚠️  Server-Extras-Installation hatte Warnungen (nicht fatal)"

step 3 "CUDA-Support verifizieren"
if ls /usr/local/lib/python3.13/dist-packages/llama_cpp/lib/ | grep -q cuda; then
  echo "✅ CUDA-Bibliotheken vorhanden:"
  ls /usr/local/lib/python3.13/dist-packages/llama_cpp/lib/ | grep cuda
else
  fail "libggml-cuda.so fehlt — pip hat die CPU-Wheel installiert (Build mit --no-binary wiederholen)"
fi

step 4 "OpenAI-kompatiblen Server starten (n_gpu_layers=-1)"
if curl -sf "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
  echo "Server läuft bereits auf Port ${PORT}"
else
  echo "Starte llama_cpp.server im Hintergrund (setsid = überlebt Zellen-Ende)"
  setsid nohup python3 -m llama_cpp.server \
    --model "$MODEL" \
    --n_gpu_layers -1 \
    --n_ctx 8192 \
    --host 0.0.0.0 --port "$PORT" \
    > "$SERVER_LOG" 2>&1 < /dev/null &
  echo $! > "$LOG_DIR/llama_server.pid"
  echo "Server-PID: $(cat "$LOG_DIR/llama_server.pid")  |  Log: $SERVER_LOG"
fi

step 5 "Health-Check (max. 300s warten)"
READY=0
for i in $(seq 1 300); do
  if curl -sf "http://localhost:${PORT}/v1/models" >/dev/null 2>&1; then
    echo "✅ Server bereit nach ${i}s"
    READY=1
    break
  fi
  # Prüfe, ob Server-Prozess gestorben ist
  if [ -f "$LOG_DIR/llama_server.pid" ] && ! kill -0 "$(cat "$LOG_DIR/llama_server.pid")" 2>/dev/null; then
    if ! pgrep -f 'python3 -m llama_cpp.server' >/dev/null 2>&1; then
      fail "Server-Prozess gestorben. Server-Log:"
    fi
  fi
  sleep 1
done
[ "$READY" = "1" ] || fail "Health-Check-Timeout. Server-Log (letzte 40 Zeilen):"
echo "--- /v1/models:"
curl -s "http://localhost:${PORT}/v1/models" || fail "/v1/models nicht erreichbar"
echo ""
echo "--- VRAM nach Serverstart:"
nvidia-smi || true

step 6 "Inference-Test (Chat-Completions + tok/s)"
python3 /content/scripts/test_inference.py || fail "Inference-Test fehlgeschlagen"

step 7 "pi-coding-Agent-Test (non-interactive)"
cd /content
pi --provider llama-cpp \
   --model qwen3.5-4B-super-coder.Q4_0 \
   --no-session \
   -p "Schreibe eine Python-Funktion fuer Binary Search in die Datei /content/output/binary_search.py. Danach kurz antworten: 'fertig'." \
   || fail "pi-Agent-Test fehlgeschlagen"
echo ""
echo "--- Erzeugte Datei /content/output/binary_search.py:"
cat /content/output/binary_search.py 2>/dev/null || fail "Agent hat keine Datei erzeugt"

step 8 "Abnahme: VRAM-Belegung (T4)"
nvidia-smi || fail "nvidia-smi fehlgeschlagen"
echo ""
if nvidia-smi | grep -qE "python3|llama"; then
  echo "✅ Modell liegt im VRAM (Prozess sichtbar)"
else
  echo "⚠️  Kein python-Prozess im VRAM sichtbar — prüfen!"
fi

echo ""
echo "================================================================"
echo " ✅ PIPELINE ERFOLGREICH ABGESCHLOSSEN: $(date)"
echo " Log: $LOG"
echo "================================================================"
