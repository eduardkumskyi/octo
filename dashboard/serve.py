#!/usr/bin/env python3
"""Minimal run-state HTTP server for the Mission Control dashboard."""
import argparse
import socketserver
import urllib.parse
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


class ThreadingHTTPServer(socketserver.ThreadingMixIn, HTTPServer):
    """Thread-per-request HTTP server (backport for Python < 3.7)."""
    daemon_threads = True

ALLOWED_RUN_FILES = {"state.json", "events.jsonl"}
PLUGIN_DIR = Path(__file__).parent


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):  # suppress default access log noise
        pass

    def _send(self, code: int, content_type: str, body: bytes) -> None:
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def do_HEAD(self) -> None:
        self.do_GET()

    def _404(self) -> None:
        self._send(404, "text/plain", b"Not Found")

    def _400(self) -> None:
        self._send(400, "text/plain", b"Bad Request")

    def do_GET(self) -> None:
        path = urllib.parse.unquote(self.path.split("?", 1)[0])  # strip query string and decode

        # Reject any path containing ".." before any other processing
        if ".." in path:
            self._400()
            return

        if path == "/":
            index = PLUGIN_DIR / "index.html"
            if index.exists():
                body = index.read_bytes()
                self._send(200, "text/html", body)
            else:
                body = b"<html><body>Mission Control (dashboard coming soon)</body></html>\n"
                self._send(200, "text/html", body)
            return

        if path.startswith("/run/"):
            name = path[len("/run/"):]
            if name not in ALLOWED_RUN_FILES:
                self._404()
                return
            run_dir = Path.cwd() / ".claude" / "octo" / "run"
            target = run_dir / name
            if not target.exists():
                self._404()
                return
            body = target.read_bytes()
            ct = "application/json" if name.endswith(".json") else "text/plain"
            self._send(200, ct, body)
            return

        self._404()


def main() -> None:
    parser = argparse.ArgumentParser(description="Mission Control dashboard server")
    parser.add_argument("--port", type=int, default=8437, help="Port to listen on (default: 8437)")
    args = parser.parse_args()

    server = None
    chosen = args.port
    for port in range(args.port, args.port + 10):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            chosen = port
            break
        except OSError:
            if port == args.port + 9:
                raise
    print(f"octo dashboard: http://127.0.0.1:{chosen}/", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
