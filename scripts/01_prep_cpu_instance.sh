#!/usr/bin/env bash
# =============================================================================
# 01_prep_cpu_instance.sh — Phase A: Vorbereitung auf der CPU-Instanz
# (spart GPU-Quota; kein T4 noetig)
#
# Ablauf in Colab (CPU-Runtime):
#   1) ZELLE (direkt, NICHT via !bash) — Drive mounten:
#        from google.colab import drive; drive.mount('/content/drive')
#      (Auth-Dialog bestätigen. Ein Bash-Skript kann das NICHT:
#       drive.mount() braucht den Colab-IPython-Kernel, in einem
#       Subprozess ist get_ipython() = None.)
#   2) dann:
#        !bash /content/scripts/01_prep_cpu_instance.sh
#
# Erledigt:
#   - Prueft den Google-Drive-Mount (bricht bei fehlendem Mount ab)
#   - Skripte + Notebook + Backup-Zip nach Drive sichern
#     (Runtime-Wechsel loescht /content — nur Drive persistiert!)
#
# Das Modell wird NICHT gesichert — es wird bei Bedarf einfach
# neu heruntergeladen (~2 Min., siehe Phase B / run_pipeline.sh).
# =============================================================================
set -euo pipefail
shopt -s nullglob

echo "════ PHASE A: Vorbereitung auf CPU-Instanz ════"

DRIVE_BASE="${DRIVE_BASE:-/content/drive/MyDrive/pi-qwen-setup}"

# 1. Google Drive — Mount-PRÜFUNG (kein Mountversuch hier möglich!)
if mountpoint -q /content/drive 2>/dev/null; then
  echo "[1/3] Google Drive: gemountet ✓"
else
  # Schein-Mount aus einem fehlgeschlagenen Durchgang aufraeumen:
  # /content/drive existiert als lokales Verzeichnis, enthaelt aber nur
  # Duplikate der /content-Dateien und ist NICHT persistent.
  if [ -d /content/drive ]; then
    rm -rf /content/drive
    echo "[1/3] Schein-Mount /content/drive (lokal, unbrauchbar) entfernt."
  fi
  if [ "${FORCE_LOCAL:-0}" = "1" ]; then
    echo "[1/3] ⚠️  FORCE_LOCAL=1 — sichere nur lokal (geht beim Runtime-Wechsel verloren!)"
    mkdir -p "$DRIVE_BASE"
  elif [ -f /content/backup_pi_qwen_setup.zip ]; then
    echo "[1/3] Zip-Restore-Weg erkannt: /content/backup_pi_qwen_setup.zip"
    echo "      Drive-Mount nicht noetig — Phase A wird uebersprungen."
    echo "      Zip herunterladen, nach dem T4-Wechsel nach /content"
    echo "      hochladen, dann RESTORE.txt / Phase B folgen."
    exit 0
  else
    echo ""
    echo "❌ Google Drive ist NICHT gemountet — und ein Bash-Skript kann das nicht!"
    echo ""
    echo "   Bitte ZUERST in einer eigenen Colab-Zelle direkt ausführen:"
    echo "       from google.colab import drive; drive.mount('/content/drive')"
    echo "   (Auth-Dialog bestätigen), dann dieses Skript erneut starten."
    echo ""
    exit 1
  fi
fi

echo "Drive-Ziel: $DRIVE_BASE"
mkdir -p "$DRIVE_BASE"

# 2. Skripte + Doku + Backup-Zip nach Drive sichern
echo "[2/3] Skripte/Notebook/Status/Backup nach Drive sichern ..."
cp -r /content/scripts "$DRIVE_BASE/"
cp /content/pi_qwen35_colab_setup.ipynb /content/AUFTRAG_STATUS.md \
   /content/COlab_Befehle_Zelle_fuer_Zelle.txt \
   /content/RESTORE.txt /content/MANIFEST.md5 \
   /content/backup_pi_qwen_setup*.zip "$DRIVE_BASE/" 2>/dev/null || true

# 3. Zusammenfassung + Verifikation
echo "[3/3] Inhalt von $DRIVE_BASE:"
ls -la "$DRIVE_BASE"

echo ""
if mountpoint -q /content/drive 2>/dev/null; then
  echo "════ PHASE A ABGESCHLOSSEN — in Google Drive persistiert ════"
else
  echo "⚠️  Achtung: Ziel ist ein LOKALES Verzeichnis (nicht persistent)!"
fi
echo "Jetzt in Colab auf T4-GPU-Runtime wechseln, dort ZUERST wieder"
echo "Drive mounten (Zelle, s. oben), dann ausführen:"
echo "  !bash /content/drive/MyDrive/pi-qwen-setup/scripts/02_prepare_t4_instance.sh"
