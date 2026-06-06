#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8788}"
LOG_FILE="${TMPDIR:-/tmp}/fanyi-mock-openai-${PORT}.log"

cd "$ROOT_DIR"
python3 Scripts/mock_openai_server.py --port "$PORT" >"$LOG_FILE" 2>&1 &
PID="$!"
trap 'kill "$PID" >/dev/null 2>&1 || true' EXIT

for _ in $(seq 1 30); do
    if curl -sS "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done

RESPONSE="$(curl -sS -X POST "http://127.0.0.1:${PORT}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d '{"model":"mock-model","messages":[{"role":"user","content":"Start Quest"}]}')"

if [[ "$RESPONSE" != *"[MOCK TRANSLATION] Start Quest"* ]]; then
    echo "Unexpected mock response:"
    echo "$RESPONSE"
    echo "Server log:"
    cat "$LOG_FILE"
    exit 1
fi

echo "PASS: mock OpenAI-compatible server responded correctly on port ${PORT}"
