================================================================================
pi-qwen-setup — Schnellstart (Deutsch)
================================================================================

INHALT
  wheels/   Vorgefertigtes llama-cpp-python 0.3.36 MIT CUDA (sm_75/T4)
            llama_cpp_python-0.3.36-py3-none-linux_x86_64.whl  (72 MB)
            sha256: fbc3704f349696cccb898881bea40ee1563f4f62657031b3d0e4200bcc9f70ca
  INSTALL.sh        Komplett-Installation auf frischer Colab-T4-Runtime
  scripts/          Alle Workflow-Skripte (Pipeline, Server, Tests, Config)
  pi_models.json    pi-Provider-Konfiguration (Quelle für ~/.pi/agent/models.json)
  AUFTRAG_STATUS.md Detaillierter Status + Learnings
  RESTORE.txt       Alternatives Restore-Verfahren
  *.ipynb / *.txt   Notebook + Zell-für-Zell-Anleitung

DAS MODELL IST NICHT DABEI — es wird bei Bedarf automatisch geladen
(qwen3.5-4B-super-coder.Q4_0.gguf, 2.6 GB, ~2 Min. von Hugging Face).

--------------------------------------------------------------------------------
SCHNELLSTART (3 Schritte in Colab)
--------------------------------------------------------------------------------
1) Paket nach /content entpacken:
     !mkdir -p /content && cd /content && tar xzf <paket>.tar.gz

2) Installieren (Wheel in ~3 s, kein Kompilieren!):
     !bash /content/pi-qwen-setup/INSTALL.sh

3) Fertig. Server läuft auf http://localhost:8000/v1

   Manueller Server-Start (falls nötig):
     !bash /content/pi-qwen-setup/scripts/start_server.sh

   Inference-Test:
     !python3 /content/pi-qwen-setup/scripts/test_inference.py

   pi-Provider testen:
     !pi --provider llama-cpp --list-models

--------------------------------------------------------------------------------
WAS FUNKTIONIERT / WAS NICHT (Stand 2026-10-09)
--------------------------------------------------------------------------------
✅ CUDA-Build (libggml-cuda.so, 1154 Symbole) — einmalig gemacht, als Wheel
✅ Installation aus Wheel: ~3 Sekunden (statt 45-90 Min. Kompilieren)
✅ Server + Modell komplett im T4-VRAM (~3,4 GB belegt)
✅ Chat-Completions: ~40 tok/s auf T4, Thinking-Mode aktiv
✅ pi-Provider-Konfiguration + --list-models

❌ pi-AGENT mit Datei-Schreiben: Der llama-cpp-python-Server hat KEINEN
   Tool-Call-Parser — er gibt Tool-Calls nie als "tool_calls" zurueck,
   sondern als Rohtext im "content". Das betrifft JEDES Modell, nicht
   nur dieses. Optionen:
   a) Normalen Chat/Completions nutzen (funktioniert einwandfrei)
   b) Native llama-server (C++) mit --tool-call-parser hermit bauen
      (weiterer ~45-Min-Build; das Modell emittiert Hermit-Format mit
      dem Tool-Namen "write", den pi kennt)
   c) Ollama als Server-Backend (parsen Tool-Calls, anderer Port 11434)

--------------------------------------------------------------------------------
UMGEBUNGSFACTEN
--------------------------------------------------------------------------------
- Python 3.13, CUDA 13.0 Toolkit, T4 (sm_75), 16 GB VRAM
- Wheel ist nur fuer identische Umgebung portabel (gleiche OS/Arch/Python)
- Server-Extras immer mitinstallieren: sse-starlette, starlette-context,
  pydantic-settings, PyYAML, numpy<2.3 (numba-Kompatibilitaet)
- Health-Endpoint: /v1/models (es gibt KEIN /health in llama-cpp-python 0.3.36)
================================================================================
