#!/usr/bin/env python3
"""Health-Check + Inference-Test fuer den lokalen llama.cpp OpenAI-Server."""
import json
import sys
import time
import urllib.request

BASE = "http://localhost:8000"


def http_json(url, payload=None):
    if payload is None:
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=30) as r:
            return json.loads(r.read())
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=300) as r:
        return json.loads(r.read())


def main():
    # 1. Health
    health = http_json(f"{BASE}/health")
    print("[health]", json.dumps(health))

    # 2. Model-Liste
    models = http_json(f"{BASE}/v1/models")
    print("[models]", json.dumps(models, indent=2)[:500])

    # 3. Chat-Completion-Test
    t0 = time.time()
    resp = http_json(f"{BASE}/v1/chat/completions", {
        "model": "qwen3.5-4B-super-coder.Q4_0",
        "messages": [
            {"role": "system", "content": "You are a helpful coding assistant."},
            {"role": "user", "content": "Schreibe eine Python-Funktion fuer Binary Search. Nur Code, keine Erklaerung."},
        ],
        "temperature": 0.6,
        "top_p": 0.95,
        "max_tokens": 512,
        "stream": False,
    })
    dt = time.time() - t0
    choice = resp["choices"][0]
    print(f"\n[inference] {dt:.1f}s | finish_reason={choice.get('finish_reason')}")
    print("[usage]", json.dumps(resp.get("usage", {})))
    print("\n----- MODELL-ANTWORT -----")
    print(choice["message"]["content"])
    print("--------------------------")

    usage = resp.get("usage", {})
    if usage.get("completion_tokens"):
        print(f"\n[perf] {usage['completion_tokens']/dt:.1f} tok/s (completion)")


if __name__ == "__main__":
    sys.exit(main())
