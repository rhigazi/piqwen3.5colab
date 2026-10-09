#!/usr/bin/env python3
"""Schreibt die pi-Provider-Konfiguration ~/.pi/agent/models.json."""
import json
import os

CFG = {
    "providers": {
        "llama-cpp": {
            "baseUrl": "http://localhost:8000/v1",
            "api": "openai-completions",
            "apiKey": "no-key-required",
            "compat": {
                "supportsDeveloperRole": False,
                "supportsReasoningEffort": False,
            },
            "models": [
                {
                    "id": "qwen3.5-4B-super-coder.Q4_0",
                    "name": "Qwen 3.5 4B Super Coder (local Q4_0)",
                    "reasoning": True,
                    "input": ["text"],
                    "contextWindow": 32768,
                    "maxTokens": 8192,
                    "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0},
                }
            ],
        }
    }
}

path = os.path.expanduser("~/.pi/agent/models.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump(CFG, f, indent=2)
print("Pi-Konfiguration geschrieben:", path)
