#!/usr/bin/env python3
"""Erzeugt das Colab-Notebook pi_qwen35_colab_setup.ipynb programmatisch."""
import json

md = lambda s: {"cell_type": "markdown", "metadata": {}, "source": s.splitlines(keepends=True)}
code = lambda s: {"cell_type": "code", "execution_count": None, "metadata": {}, "outputs": [], "source": s.splitlines(keepends=True)}

cells = [
md("""# pi-coding-agent + qwen3.5-4B-super-coder in Google Colab (T4 GPU)

Setup: lokales GGUF-Modell (`jica98/qwen3.5-4B-super-coder`, **Q4_0**) wird mit `llama-cpp-python` (CUDA) als OpenAI-kompatibler Server auf Port 8000 gehostet, und der CLI-Agent `@earendil-works/pi-coding-agent` greift darauf zu.

**⚠️ Wichtige Korrektur:** Die Datei `qwen3.5-4B-super-coder.BF16-mmproj.gguf` im Repo ist nur die **Multimodal-Projektor-Datei (mmproj)** — sie ist *nicht* das Hauptmodell und kann nicht für Text-Inference geladen werden. Das eigentliche Modell ist **`qwen3.5-4B-super-coder.Q4_0.gguf`** (~2.6 GB), das problemlos in den 16 GB VRAM der T4 passt."""),

md("""## 1. Laufzeit prüfen (T4 GPU, CUDA)"""),
code("""!nvidia-smi
import sys, os
print('Python:', sys.version)
print('CUDA_HOME:', os.environ.get('CUDA_HOME', '/usr/local/cuda'))"""),

md("""## 2. llama-cpp-python mit CUDA-Unterstützung installieren

Kompiliert llama.cpp mit `GGML_CUDA=on` (dauert ca. 10–20 Minuten auf Colab)."""),
code("""%pip install --upgrade cmake
import os
os.environ['CMAKE_ARGS'] = '-DGGML_CUDA=on'
%pip install llama-cpp-python --force-reinstall --upgrade --no-cache-dir"""),

md("""## 3. Modell herunterladen (korrekte GGUF-Hauptdatei)"""),
code("""from huggingface_hub import hf_hub_download
import os

MODEL_PATH = hf_hub_download(
    repo_id='jica98/qwen3.5-4B-super-coder',
    filename='qwen3.5-4B-super-coder.Q4_0.gguf',
    local_dir='/content/models',
)
print('Modell gespeichert unter:', MODEL_PATH)
print('Groesse: %.2f GB' % (os.path.getsize(MODEL_PATH)/1e9))"""),

md("""## 4. OpenAI-kompatiblen Server im Hintergrund starten

Alle Layer auf die T4 GPU auslagern (`n_gpu_layers=-1`)."""),
code("""import subprocess, time, urllib.request

MODEL_PATH = '/content/models/qwen3.5-4B-super-coder.Q4_0.gguf'
PORT = 8000

def health():
    try:
        with urllib.request.urlopen(f'http://localhost:{PORT}/health', timeout=2) as r:
            return r.status == 200
    except Exception:
        return False

if not health():
    log = open('/content/llama_server.log', 'w')
    server = subprocess.Popen(
        ['python3', '-m', 'llama_cpp.server',
         '--model', MODEL_PATH,
         '--n_gpu_layers', '-1',
         '--n_ctx', '8192',
         '--host', '0.0.0.0', '--port', str(PORT)],
        stdout=log, stderr=subprocess.STDOUT,
        start_new_session=True,  # entkoppelt von der Zelle -> ueberlebt,
    )                             # auch wenn die Zelle endet (Colab-sicher)
    print('Server PID:', server.pid)
    for i in range(300):
        if server.poll() is not None:
            raise RuntimeError('Server gestorben. Log:\\n' + open('/content/llama_server.log').read()[-3000:])
        if health():
            print(f'Server bereit nach {i}s')
            break
        time.sleep(1)
else:
    print('Server laeuft bereits')"""),

code("""!curl -s http://localhost:8000/v1/models | python3 -m json.tool
!nvidia-smi | grep -A3 'Processes'"""),

md("""## 5. Inference-Test (OpenAI-Chat-Completions-API)"""),
code("""from openai import OpenAI
import time

client = OpenAI(base_url='http://localhost:8000/v1', api_key='no-key-required')

t0 = time.time()
resp = client.chat.completions.create(
    model='qwen3.5-4B-super-coder.Q4_0',
    messages=[
        {'role': 'system', 'content': 'You are a helpful coding assistant.'},
        {'role': 'user', 'content': 'Schreibe eine Python-Funktion fuer Binary Search. Nur Code.'},
    ],
    temperature=0.6, top_p=0.95, max_tokens=512,
)
dt = time.time() - t0
print(f'[{dt:.1f}s | {resp.usage.completion_tokens/dt:.0f} tok/s]')
print()
print(resp.choices[0].message.content)"""),

md("""## 6. pi-coding-agent installieren"""),
code("""!npm install -g --ignore-scripts @earendil-works/pi-coding-agent
!pi --version"""),

md("""## 7. Pi-Konfiguration auf den lokalen Endpoint zeigen lassen

`~/.pi/agent/models.json` registriert einen eigenen Provider `llama-cpp` mit `openai-completions`-API. `supportsDeveloperRole`/`supportsReasoningEffort` werden deaktiviert, da der llama.cpp-Server diese Felder nicht versteht."""),
code("""import json, os

cfg = {
    'providers': {
        'llama-cpp': {
            'baseUrl': 'http://localhost:8000/v1',
            'api': 'openai-completions',
            'apiKey': 'no-key-required',
            'compat': {
                'supportsDeveloperRole': False,
                'supportsReasoningEffort': False,
            },
            'models': [{
                'id': 'qwen3.5-4B-super-coder.Q4_0',
                'name': 'Qwen 3.5 4B Super Coder (local Q4_0)',
                'reasoning': True,
                'input': ['text'],
                'contextWindow': 32768,
                'maxTokens': 8192,
                'cost': {'input': 0, 'output': 0, 'cacheRead': 0, 'cacheWrite': 0},
            }],
        }
    }
}

os.makedirs(os.path.expanduser('~/.pi/agent'), exist_ok=True)
with open(os.path.expanduser('~/.pi/agent/models.json'), 'w') as f:
    json.dump(cfg, f, indent=2)
print('Konfiguration geschrieben: ~/.pi/agent/models.json')"""),

md("""## 8. Agent ausführen (Non-Interactive-Test)"""),
code("""%%bash
cd /content
pi --provider llama-cpp --model qwen3.5-4B-super-coder.Q4_0 --no-session -p "Schreibe eine Python-Funktion fuer Binary Search in /content/output/binary_search.py"
cat /content/output/binary_search.py"""),

md("""## 9. Abnahme: VRAM-Belegung prüfen

Das Modell (~1.6 GB Q4_0-Gewichte + KV-Cache) muss vollständig im T4-VRAM liegen."""),
code("""!nvidia-smi"""),
]

nb = {
    "cells": cells,
    "metadata": {
        "accelerator": "GPU",
        "colab": {"name": "pi-coding-agent + qwen3.5-4B-super-coder (T4)"},
        "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
        "language_info": {"name": "python"},
    },
    "nbformat": 4,
    "nbformat_minor": 0,
}

with open('/content/pi_qwen35_colab_setup.ipynb', 'w') as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)

# validieren
json.load(open('/content/pi_qwen35_colab_setup.ipynb'))
print('Notebook geschrieben und validiert: /content/pi_qwen35_colab_setup.ipynb')
