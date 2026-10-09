#!/usr/bin/env bash
# Startet den llama.cpp OpenAI-kompatiblen Server mit dem qwen3.5-4B-super-coder Q4_0 Modell
# auf der T4 GPU (alle Layer ausgelagert) und wartet bis /v1/models erreichbar ist.
# (Hinweis: llama-cpp-python 0.3.36 hat KEIN /health-Endpoint — /v1/models ist der
#  korrekte Readiness-Endpunkt.)
set -euo pipefail

MODEL_PATH="${MODEL_PATH:-/content/models/qwen3.5-4B-super-coder.Q4_0.gguf}"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
LOG_FILE="${LOG_FILE:-/content/logs/llama_server.log}"
HEALTH_URL="${HEALTH_URL:-http://localhost:${PORT}/v1/models}"

mkdir -p "$(dirname "$LOG_FILE")"

if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
  echo "[start_server] Server laeuft bereits auf Port ${PORT}."
  exit 0
fi

echo "[start_server] Starte llama_cpp.server auf ${HOST}:${PORT}"
echo "[start_server] Modell: ${MODEL_PATH}"
echo "[start_server] Log:    ${LOG_FILE}"

nohup python3 -m llama_cpp.server \
  --model "$MODEL_PATH" \
  --n_gpu_layers -1 \
  --n_ctx 8192 \
  --host "$HOST" \
  --port "$PORT" \
  > "$LOG_FILE" 2>&1 &

SERVER_PID=$!
echo "$SERVER_PID" > /content/logs/llama_server.pid
echo "[start_server] PID: $SERVER_PID"

# Warte maximal 240s bis der Server healthy ist
for i in $(seq 1 240); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "[start_server] FEHLER: Server-Prozess gestorben. Letzte Logzeilen:"
    tail -30 "$LOG_FILE"
    exit 1
  fi
  if curl -sf "$HEALTH_URL" >/dev/null 2>&1; then
    echo "[start_server] Server ist bereit nach ${i}s."
    curl -s "$HEALTH_URL" | python3 -m json.tool || true
    exit 0
  fi
  sleep 1
done

echo "[start_server] TIMEOUT: Server wurde nicht bereit. Log:"
tail -30 "$LOG_FILE"
exit 1
