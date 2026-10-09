#!/usr/bin/env bash
# =============================================================================
# 03_persist_artifacts.sh — Build-Artefakte + Skripte nach Google Drive sichern
#
# WICHTIG: Drive-Mount muss VORHER in einer Colab-Zelle direkt erfolgen:
#     from google.colab import drive; drive.mount('/content/drive')
# (drive.mount() funktioniert nicht aus einem Bash-Skript heraus!)
#
# Was gesichert wird:
#   - /content/wheels/*.whl        (~72 MB, CUDA-Build von llama-cpp-python)
#   - /content/scripts/*.sh/.py    (kompletter Workflow)
#   - /content/AUFTRAG_STATUS.md, RESTORE.txt, COlab_Befehle_*.txt
#   - /content/pi_qwen35_colab_setup.ipynb
#   - /content/backup_pi_qwen_setup*.zip
#   - MD5-Manifest der Artefakte
# =============================================================================
set -euo pipefail

DEST="/content/drive/MyDrive/pi-qwen-setup"

if ! mountpoint -q /content/drive; then
  echo "❌ /content/drive ist NICHT gemountet."
  echo "   Führe zuerst in einer Colab-Zelle AUSFÜHRLICH DIREKT (nicht via !bash) aus:"
  echo "       from google.colab import drive; drive.mount('/content/drive')"
  exit 1
fi

mkdir -p "$DEST/wheels" "$DEST/scripts" "$DEST/logs"

echo "▶ Sichere CUDA-Wheel ..."
cp -fv /content/wheels/*.whl "$DEST/wheels/" 2>/dev/null || echo "⚠️ kein Wheel in /content/wheels"

echo "▶ Sichere Skripte ..."
cp -fv /content/scripts/*.sh /content/scripts/*.py "$DEST/scripts/" 2>/dev/null || true

echo "▶ Sichere Doku + Backup ..."
cp -fv /content/AUFTRAG_STATUS.md /content/RESTORE.txt "$DEST/" 2>/dev/null || true
cp -fv /content/COlab_Befehle_Zelle_fuer_Zelle.txt "$DEST/" 2>/dev/null || true
cp -fv /content/pi_qwen35_colab_setup.ipynb "$DEST/" 2>/dev/null || true
cp -fv /content/backup_pi_qwen_setup*.zip "$DEST/" 2>/dev/null || true

echo "▶ Erstelle MD5-Manifest ..."
( cd "$DEST" && find . -type f -exec md5sum {} \; | sort > MANIFEST.md5 )

echo ""
echo "✅ Gesichert nach: $DEST"
echo "   Inhalt:"
du -sh "$DEST"/* 2>/dev/null | sed 's/^/     /'
echo ""
echo "🚀 Installation auf einer frischen T4-Runtime danach in ~3 Sekunden:"
echo "     pip install --no-deps --force-reinstall $DEST/wheels/llama_cpp_python-*.whl"
echo "     pip install -q sse-starlette 'starlette-context>=0.3.6,<0.4' pydantic-settings PyYAML 'numpy<2.3'"
