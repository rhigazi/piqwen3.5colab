# Aufgaben-Status: pi-coding-agent + qwen3.5-4B in Colab (T4)

Stand: 2026-10-09 ~10:40 UTC

## 1. Ziel

Lokales GGUF-Modell `jica98/qwen3.5-4B-super-coder` via
`llama-cpp-python` (CUDA) als OpenAI-kompatibler Server auf
Port 8000 hosten, damit der CLI-Agent `@earendil-works/pi-coding-agent`
(`pi`, v0.74.2) darauf zugreift und Code-Generierungsaufgaben ausführt.
Abnahme: funktionierender Agent-Test + `nvidia-smi` zeigt Modell
vollständig im T4-VRAM.

## 2. Umgebungsfakten (verifiziert)

- GPU: Tesla T4, 15360 MiB VRAM, CUDA 13.0 Toolkit (`nvcc` in `/usr/local/cuda/bin`)
- Architektur: sm_75 (Turing) — CUDA-Kernel werden dafür kompiliert
- Python 3.13.15, pip 24.1.2, Node v20.19.0, npm 10.8.2, cmake 3.31.10
- RAM 12 GiB, Disk 70 GiB frei, **nur 2 vCPU** (Build daher ~60 Min.)
- Arbeitsverzeichnis: `/content`
- Arbeitsweise: Vorbereitung auf **CPU-Instanz** (GPU-Quota sparen),
  CUDA-Build + Inference auf **T4-Runtime**

## 3. WICHTIGE KORREKTUR (war im ursprünglichen Snippet falsch)

- `qwen3.5-4B-super-coder.BF16-mmproj.gguf` (675 MB) ist **nur die
  Multimodal-Projektor-Datei (mmproj)** — KEIN ladbares Textmodell.
  Darf nicht als `--model` übergeben werden.
- Das korrekte Hauptmodell ist **`qwen3.5-4B-super-coder.Q4_0.gguf`**
  (~2.6 GB, Q4_0) — die einzige GGUF-Hauptdatei im Repo.
- Passt problemlos in 16 GB VRAM (~1.6 GB Gewichte + kleiner KV-Cache;
  Hybrid-Architektur Gated-DeltaNet/Attention, nur 8 full-KV-Layer).
- **Modell wird NICHT persistiert** (weder Zip noch Drive): es wird bei
  Bedarf einfach neu geladen (~2 Min.).
- Das Repo ist ein **LoRA-Fine-tune** (adapter_model.safetensors +
  chat_template.jinja). Die Fine-Tune emittiert Tool-Calls im
  **Hermit-XML-Stil** (`...`) mit Tool-Name `write`.

## 4. ERLEDIGT ✅

1. **Pi-Provider konfiguriert**: `/root/.pi/agent/models.json` mit Provider
   `llama-cpp` (`baseUrl http://localhost:8000/v1`, `api openai-completions`,
   `apiKey no-key-required`, `compat.supportsDeveloperRole=false`,
   `compat.supportsReasoningEffort=false`, Modell `qwen3.5-4B-super-coder.Q4_0`,
   contextWindow 32768, maxTokens 8192, reasoning=true).
   Verifiziert: `pi --provider llama-cpp --list-models` listet das Modell.
2. **Deliverables erstellt**:
    - `/content/backup_pi_qwen_setup.zip` — Backup (23,8 KB, 14 Dateien)
    - `/content/pi_qwen35_colab_setup.ipynb` — vollständiges Notebook
    - `/content/COlab_Befehle_Zelle_fuer_Zelle.txt` — 10 Zellen zum Kopieren
    - `/content/scripts/01_prep_cpu_instance.sh` — Phase A (CPU-Instanz)
    - `/content/scripts/02_prepare_t4_instance.sh` — Phase B (T4-Runtime)
    - `/content/scripts/03_persist_artifacts.sh` — Drive-Sicherung (optional)
    - `/content/scripts/run_pipeline.sh` — Gesamt-Pipeline (Wheel-Cache)
    - `/content/scripts/start_server.sh` — Server-Start + `/v1/models`-Check
    - `/content/scripts/test_inference.py` — OpenAI-API-Test mit tok/s
    - `/content/scripts/test_pi.sh` — Agent-Test non-interactive (`-p`)
    - `/content/scripts/write_pi_config.py` — schreibt `~/.pi/agent/models.json`
    - `/content/scripts/run_all.sh`, `/content/scripts/build_notebook.py`
3. **CUDA-Build ABGESCHLOSSEN** (~60 Min auf 2 vCPU, nur sm_75):
   `libggml-cuda.so` (41,9 MB, 1154 CUDA-Symbole) installiert.
4. **⚡ WHEEL-ARTIFAKT ERSTELLT** ("nie wieder bauen"):
   `/content/wheels/llama_cpp_python-0.3.36-py3-none-linux_x86_64.whl`
   (72 MB, sha256 `fbc3704f349696cccb898881bea40ee1563f4f62657031b3d0e4200bcc9f70ca`).
   Installation daraus verifiziert: **2,9 Sekunden**
   (`pip install --no-deps --force-reinstall`), CUDA-Lib danach intakt.
5. **Server läuft** auf Port 8000 mit `n_gpu_layers=-1`, Modell
   komplett im VRAM (~3,4 GB), Inference-Test: **~41,6 tok/s**,
   sinnvoller Code-Output, Thinking-Mode aktiv.
6. **Drei Pipeline-Bugs gefixt**:
   - Server-Extras fehlten: `sse-starlette`, `starlette-context<0.4`,
     `pydantic-settings`, `PyYAML` (jetzt in Pipeline + INSTALL.sh)
   - **`diskcache` ist Laufzeit-Dep**: `import llama_cpp` schlägt
     ohne fehl (ModuleNotFoundError) — auf frischen Colab-Instanzen
     NICHT vorinstalliert → jetzt explizit in der Installationsliste
   - llama-cpp-python 0.3.36 hat **kein** `/health`-Endpoint →
     alle Health-Checks auf `/v1/models` umgestellt
7. **ZERO-COMPILE-GARANTIE** (User-Wunsch: nie wieder kompilieren):
   alle pip-Installs laufen mit `--only-binary :all:` — pip baut
   dann NIE aus Quelle (Fehler statt Kompilierung). Vollständige
   Abhängigkeitsliste (alles reine Python-Pakete, cp313-Wheels):
   sse-starlette, starlette-context, pydantic-settings, PyYAML,
   numpy<2.3, diskcache, typing-extensions, huggingface_hub,
   fastapi, uvicorn — plus das vorgefertigte CUDA-Wheel selbst.
8. **BACKUP-ARCHIVE** (ohne Drive, ohne Modell):
   - `/content/pi-qwen-setup-backup.zip` (71 MB, 18 Dateien)
   - `/content/pi-qwen-setup-package.tar.gz` (gleicher Inhalt)
   Inhalt: CUDA-Wheel + INSTALL.sh + README.txt + Skripte + Doku.
   Schnellstart: nach /content entpacken,
   `!bash /content/pi-qwen-setup/INSTALL.sh` → fertig in ~3 Min.

## 5. OFFEN ⏳

**A) pi-Agent mit Datei-Schreiben funktioniert NICHT** (kein Build-Problem):
Der llama-cpp-python-Server (0.3.36) hat **keinen Tool-Call-Parser** —
er gibt Tool-Calls nie als `tool_calls` im API-Response zurück, sondern
als Rohtext im `content` (verifiziert: Request mit `tools` → Response
enthält nur `content`+`role`). Das betrifft **jedes** Modell.
pi hat zwar ein passendes `write`-Tool, bekommt den Call aber nie
strukturiert. Optionen:
- a) Chat/Completions normal nutzen (funktioniert einwandfrei, ~40 tok/s)
- b) Nativen C++ `llama-server` mit `--tool-call-parser hermit` bauen
  (weiterer ~45-Min-Build; das Modell emittiert Hermit-Format, Tool-Name
  `write` passt zu pi) — dann pi gegen diesen Server (Port z.B. 8080)
- c) Ollama als Backend (parst Tool-Calls, OpenAI-API auf Port 11434)

**B) Zwei-Phasen-Workflow (GPU-Quota sparen) — NUR FALLS OHNE PAKET:**
```
# Phase A (CPU-Instanz): Drive mounten direkt in Zelle:
from google.colab import drive; drive.mount('/content/drive')
!bash /content/scripts/01_prep_cpu_instance.sh
# Phase B (T4-Runtime): Drive wieder mounten, dann:
!bash /content/drive/MyDrive/pi-qwen-setup/scripts/02_prepare_t4_instance.sh
!bash /content/scripts/run_pipeline.sh
```
⚠️ `drive.mount()` funktioniert **nur direkt in einer Zelle**.
⚠️ Colab löscht `/content` beim Runtime-Wechsel.
**Empfohlen wird stattdessen das Download-Paket (§4.7).**

**Pipeline-Schritte (run_pipeline.sh) im Detail:**
1. GPU prüfen (`nvidia-smi`)
2. **Wheel-Cache prüfen** → Installation in ~3 s; nur ohne Cache:
   Source-Build mit `GGML_CUDA=on` (~45–90 Min auf 2 vCPU).
   ⚠️ `--no-binary llama-cpp-python` ist beim Build PFLICHT.
   Danach: Server-Extras + `numpy<2.3` (numba-Kompat).
3. CUDA-Verifikation: `libggml-cuda.so` muss existieren
4. Server-Start via `setsid` (überlebt Zellen-Ende)
5. Bereitschaft via `/v1/models` (max. 120s) + VRAM nach Serverstart
6. Inference-Test (Chat-Completions, tok/s; erwartet ~30–80 tok/s auf T4)
7. Agent-Test: `pi --provider llama-cpp --model qwen3.5-4B-super-coder.Q4_0
   --no-session -p "..."` → ⚠️ siehe 5A (Tool-Parsing fehlt)
8. Abnahme: `nvidia-smi` → VRAM belegt durch python3/llama-server

## 6. Learnings (für Fortsetzung relevant)

- **Wheel-Strategie**: CUDA-Wheel einmal bauen (braucht keine GPU, nur
  CUDA-Toolkit + CPU), als Artefakt sichern, danach in ~3 s installieren.
  `wheel pack` aus installierten Dateien: `cp -r llama_cpp
  llama_cpp_python-*.dist-info /tmp/wheelpack/ && python3 -m wheel pack
  /tmp/wheelpack -d /content/wheels`.
- **`diskcache` ist Laufzeit-Dep** von llama-cpp-python (`import llama_cpp`
  schlägt ohne fehl!) — in jeder Installationsliste mitführen.
- **`pip install --only-binary :all:`** erzwingt Fertig-Wheels — pip baut
  dann niemals aus Quelle (Zero-Compile-Garantie für frische Instanzen).
- Server-Extras von llama-cpp-python 0.3.36: `uvicorn`, `fastapi`,
  `pydantic-settings`, `sse-starlette`, `starlette-context<0.4`, `PyYAML`
  (fastapi/uvicorn sind in Colab schon da).
- llama-cpp-python-Server hat **kein** `/health` → `/v1/models` nutzen.
- `llama_cpp.server`-CLI-Args mit Unterstrichen: `--n_gpu_layers -1`,
  `--n_ctx`, `--host`, `--port`.
- llama.cpp-Server ignoriert das `model`-Feld in /v1/chat/completions meist —
  Modell-ID in models.json = Dateiname ist trotzdem richtig.
- Pi-Konfiguration liegt in `~/.pi/agent/models.json`
  (Schema: providers → baseUrl/api/apiKey/compat/models). `compat`
  deaktivieren: llama.cpp-Server versteht weder `developer`-Role noch
  `reasoning_effort`.
- Pi-Non-Interactive-Modus: `pi -p "<prompt>"` (alias `--print`), Optionen
  `--provider`, `--model`, `--no-session`. pi-Tools: bash, edit, read,
  write, ls, find, grep, ... (Tool-Name des Modells `write` passt!)
- Colab: Hintergrund-Prozesse aus beendeten Zellen sterben können → Server
  mit `setsid`/`start_new_session=True` starten; lange Builds im Vordergrund.
- **`google.colab.drive.mount()` nur direkt in einer Zelle aufrufbar**
  (braucht `get_ipython().kernel` für den Auth-Dialog).
- Browser-Downloads bekommen ggf. ein ` (1)`-Suffix → Globs nutzen.
- Empfohlene Sampling-Parameter (Model Card): temperature 0.6, top_p 0.95.
- Modell hat Thinking-Mode (emittiert Denkanweisungen im Content).
- Nur **2 vCPU** in Colab → CUDA-Build ~60 Min (nicht 15–30).
  Bereits optimiert: nur sm_75 wird kompiliert.

## 7. Datei-Inventar

```
/content/
├── pi-qwen-setup-backup.zip       # BACKUP (Wheel+Skripte+Doku, 71 MB)
├── pi-qwen-setup-package.tar.gz   # gleicher Inhalt, tar.gz-Format
├── wheels/llama_cpp_python-0.3.36-py3-none-linux_x86_64.whl  (72 MB)
├── backup_pi_qwen_setup.zip        # Backup (23,8 KB)
├── COlab_Befehle_Zelle_fuer_Zelle.txt
├── pi_qwen35_colab_setup.ipynb
├── AUFTRAG_STATUS.md               # diese Datei
├── models/qwen3.5-4B-super-coder.Q4_0.gguf   (2.6 GB, wird bei Bedarf neu geladen)
├── package/pi-qwen-setup/          # Paket-Quellverzeichnis (ENTPACKTE Version)
│   ├── INSTALL.sh                  # Vollinstallation auf frischer Runtime
│   ├── README.txt                  # Schnellstart + Known Issues
│   ├── wheels/…, scripts/…, pi_models.json, Doku
├── scripts/                        # alle Skripte (gepatcht)
└── logs/                           # run.log, llama_server.log, pi_test.log
/root/.pi/agent/models.json         # Pi-Provider-Konfiguration
```

## 8. Wiederaufnahme-Checkliste

**Primärer Weg (Download-Paket, kein Drive):**
1. `pi-qwen-setup-package.tar.gz` nach /content hochladen + entpacken
2. `!bash /content/pi-qwen-setup/INSTALL.sh`
3. Fertig (Server läuft, Modell im VRAM, pi konfiguriert)

**Falls Agent-Tool-Calls gewünscht:** siehe §5A (Option b oder c).

Bricht etwas ab → letzte 40 Zeilen (oder `/content/logs/run.log`)
zur Analyse geben.

- [x] Phase A erledigt (Skripte + Backup)
- [x] Phase B erledigt (Modell geladen, pi installiert, Config geschrieben)
- [x] libggml-cuda.so vorhanden (CUDA-Build OK)
- [x] Wheel-Artefakt erstellt + Install-Test (2,9 s)
- [x] Zero-Compile-Garantie (--only-binary, diskcache etc.)
- [x] Server läuft auf Port 8000 mit n_gpu_layers=-1
- [x] /v1/models 200 OK, Modell im VRAM (~3,4 GB)
- [x] Inference-Test: ~41,6 tok/s, sinnvoller Code
- [ ] `pi -p "..."` schreibt binary_search.py — BLOCKIERT (§5A: kein Tool-Parser)
- [ ] nvidia-smi zeigt VRAM-Belegung durch llama-server
- [ ] Falls CUDA-Build nochmal nötig: nur sm_75 (`-DCMAKE_CUDA_ARCHITECTURES=75`)
