#!/usr/bin/env python3
import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from time import time


def extract_user_text(messages):
    for message in reversed(messages):
        if message.get("role") == "user":
            return str(message.get("content", ""))
    return ""


def make_translation(text):
    compact = " ".join(text.strip().split())
    if not compact:
        compact = "empty input"
    if len(compact) > 180:
        compact = compact[:177] + "..."
    return f"[MOCK TRANSLATION] {compact}"


class Handler(BaseHTTPRequestHandler):
    server_version = "FanyiMockOpenAI/0.1"

    def do_POST(self):
        if self.path not in ("/v1/chat/completions", "/chat/completions"):
            self.send_json(404, {"error": {"message": f"unsupported path: {self.path}"}})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            payload = json.loads(body.decode("utf-8"))
        except Exception as exc:
            self.send_json(400, {"error": {"message": f"invalid JSON: {exc}"}})
            return

        messages = payload.get("messages", [])
        content = make_translation(extract_user_text(messages))
        response = {
            "id": f"chatcmpl-mock-{int(time())}",
            "object": "chat.completion",
            "created": int(time()),
            "model": payload.get("model", "mock-model"),
            "choices": [
                {
                    "index": 0,
                    "message": {
                        "role": "assistant",
                        "content": content,
                    },
                    "finish_reason": "stop",
                }
            ],
        }
        self.send_json(200, response)

    def do_GET(self):
        if self.path == "/health":
            self.send_json(200, {"ok": True})
        else:
            self.send_json(404, {"error": {"message": f"unsupported path: {self.path}"}})

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args))

    def send_json(self, status, payload):
        data = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main():
    parser = argparse.ArgumentParser(description="Local OpenAI-compatible mock server for FanyiBar manual UAT.")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"Fanyi mock OpenAI server listening on http://{args.host}:{args.port}/v1")
    print("Press Ctrl+C to stop.")
    server.serve_forever()


if __name__ == "__main__":
    main()
