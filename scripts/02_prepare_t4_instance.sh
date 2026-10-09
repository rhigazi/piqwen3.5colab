#!/usr/bin/env bash
# =============================================================================
# 02_prepare_t4_instance.sh — Phase B: T4-Runtime vorbereiten
# (nach dem Wechsel von CPU- auf T4-GPU-Runtime in Colab)
#
# In Colab (T4-Runtime) ausführen:
#   !bash /content/drive/MyDrive/pi-qwen-setup/scripts/02_prepare_t4_instance.sh
#
# Erledigt:
#   - Drive mounten, Skripte zurück nach /content holen
#   - Modell (Q4_0, 2.6 GB, ~2 Min.) nach /content/models laden
#   - pi-coding-agent installieren
#   - Pi-Provider-Konfiguration schreiben
# Danach: !bash /content/scripts/run_pipeline.sh
# =============================================================================
set -euo pipefail

echo "════ PHASE B: T4-Runtime vorbereiten ════"

# 1. Skripte nach /content holen — zwei Wege:
#    a) Google Drive gemountet (Phase A hat dorthin gesichert)
#    b) Zip-Restore: backup_pi_qwen_setup.zip wurde nach /content
#       hochgeladen und entpackt (siehe RESTORE.txt)
# WICHTIG: drive.mount() braucht den Colab-IPython-Kernel (Auth-Dialog
# im UI) und kann NICHT aus einem Bash-Skript laufen (get_ipython()
# = None). Drive also VORHER in einer eigenen Colab-Zelle mounten:
#   from google.colab import drive; drive.mount('/content/drive')
DRIVE_BASE="${DRIVE_BASE:-/content/drive/MyDrive/pi-qwen-setup}"

if mountpoint -q /content/drive 2>/dev/null && [ -d "$DRIVE_BASE/scripts" ]; then
  echo "[1/4] Google Drive: gemountet ✓ — Skripte aus Drive nach /content ..."
  rm -rf /content/scripts
  cp -r "$DRIVE_BASE/scripts" /content/scripts
  chmod +x /content/scripts/*.sh
  cp "$DRIVE_BASE"/*.ipynb "$DRIVE_BASE"/*.md "$DRIVE_BASE"/*.txt /content/ 2>/dev/null || true
elif [ -d /content/scripts ]; then
  echo "[1/4] Kein Drive-Mount — Skripte bereits in /content (Zip-Restore)."
else
  echo "❌ Weder Google Drive gemountet ($DRIVE_BASE fehlt)"
  echo "   noch /content/scripts vorhanden."
  echo ""
  echo "   Weg a) Drive in einer Colab-Zelle direkt mounten:"
  echo "        from google.colab import drive; drive.mount('/content/drive')"
  echo "   Weg b) backup_pi_qwen_setup.zip nach /content hochladen und"
  echo "        entpacken (siehe RESTORE.txt), dann erneut starten."
  exit 1
fi

# 3. Modell laden (wird bei jedem Runtime-Wechsel neu geladen, ~2 Min.)
echo "[2/4] Modell qwen3.5-4B-super-coder.Q4_0.gguf (2.6 GB) laden ..."
mkdir -p /content/models
MODEL_GGUF="qwen3.5-4B-super-coder.Q4_0.gguf"
if [ -f "/content/models/$MODEL_GGUF" ]; then
  echo "Modell bereits vorhanden"
else
  python3 -c "from huggingface_hub import hf_hub_download; \
              hf_hub_download(repo_id='jica98/qwen3.5-4B-super-coder', \
                              filename='$MODEL_GGUF', local_dir='/content/models')"
  echo "Modell: $(du -h /content/models/$MODEL_GGUF | cut -f1)"
fi

# 4. pi-coding-agent installieren
echo "[3/4] pi-coding-agent installieren ..."
if command -v pi >/dev/null 2>&1; then
  echo "pi bereits installiert: $(pi --version 2>&1 | head -1)"
else
  npm install -g --ignore-scripts @earendil-works/pi-coding-agent
  pi --version
fi

# 5. Pi-Provider-Konfiguration
echo "[4/4] Pi-Provider konfigurieren ..."
python3 /content/scripts/write_pi_config.py
pi --provider llama-cpp --list-models || true

echo ""
echo "════ PHASE B ABGESCHLOSSEN ════"
echo "Jetzt die Gesamt-Pipeline starten (CUDA-Build + Server + Tests):"
echo "  !bash /content/scripts/run_pipeline.sh"
