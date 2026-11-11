#!/usr/bin/env python3
"""Local CKA ExamUI: question panel + timer + embedded noVNC remote desktop.

Serves the exam console on :8080, the noVNC JS from vendor/novnc, and a small
API used by the frontend. It only launches Firefox for kubernetes.io docs.
"""

from __future__ import annotations

import argparse
import html as html_module
import json
import mimetypes
import os
import re
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

try:
    import markdown as markdown_lib
except ImportError:  # pragma: no cover - installed by provisioning
    markdown_lib = None

SERIES_TITLES = {
    "series-a": "Series A — Security, policy and configuration",
    "series-b": "Series B — Troubleshooting and node operations",
    "series-c": "Series C — Workloads, storage and networking",
    "series-d": "Series D — Very difficult mixed scenarios",
}

SERIES_RE = re.compile(r"^series-[a-z]$")
SLUG_RE = re.compile(r"^q[0-9]{2}-[a-z0-9-]+$")


def is_relative_to(path: Path, base: Path) -> bool:
    try:
        path.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def discover_series(labs_dir: Path) -> list[dict]:
    series = []
    if not labs_dir.is_dir():
        return series

    for series_dir in sorted(labs_dir.glob("series-*"), key=lambda p: p.name):
        if not series_dir.is_dir():
            continue
        questions = []
        for qdir in sorted(series_dir.glob("q*"), key=lambda p: p.name):
            qfile = qdir / "question.md"
            if not qfile.is_file():
                continue
            text = qfile.read_text(encoding="utf-8", errors="replace")
            title = ""
            for line in text.splitlines():
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
            questions.append({"slug": qdir.name, "title": title or qdir.name})
        series.append(
            {
                "id": series_dir.name,
                "title": SERIES_TITLES.get(series_dir.name, series_dir.name),
                "questions": questions,
            }
        )
    return series


def question_payload(labs_dir: Path, series: str, slug: str) -> dict | None:
    if not SERIES_RE.fullmatch(series) or not SLUG_RE.fullmatch(slug):
        return None

    qdir = labs_dir / series / slug
    qfile = qdir / "question.md"
    if not qfile.is_file() or not is_relative_to(qfile, labs_dir):
        return None

    text = qfile.read_text(encoding="utf-8", errors="replace")
    title = ""
    for line in text.splitlines():
        if line.startswith("# "):
            title = line[2:].strip()
            break

    if markdown_lib is not None:
        rendered = markdown_lib.markdown(
            text,
            extensions=["fenced_code", "tables", "sane_lists"],
        )
    else:
        rendered = f"<pre>{html_module.escape(text)}</pre>"

    return {
        "title": title or slug,
        "dir": f"{series}/{slug}",
        "markdown": text,
        "html": rendered,
    }


def is_allowed_docs_url(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    host = (parsed.hostname or "").lower()
    return host == "kubernetes.io" or host.endswith(".kubernetes.io")


def open_in_firefox(url: str) -> tuple[bool, str]:
    if not is_allowed_docs_url(url):
        return False, "Only kubernetes.io documentation can be opened in the exam Firefox."
    env = os.environ.copy()
    env.setdefault("DISPLAY", ":1")
    try:
        subprocess.Popen(
            ["firefox", "--new-tab", url],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except FileNotFoundError:
        return False, "Firefox is not installed."
    return True, "Opened in the remote Firefox."


class ExamUIHandler(BaseHTTPRequestHandler):
    server_version = "CKAExamUI/1.0"
    labs_dir = Path("/home/candidate/cka-practice-labs")
    static_dir = Path(__file__).resolve().parent / "static"
    vendor_dir = Path(__file__).resolve().parent / "vendor" / "novnc"
    vnc_password = "cka-lab1"
    ws_port = 6080

    def log_message(self, fmt: str, *args) -> None:  # noqa: D401 - stdlib signature
        print(f"{self.address_string()} - {fmt % args}", flush=True)

    def send_text(self, text: str, status: int = 200, content_type: str = "text/plain; charset=utf-8") -> None:
        data = text.encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    def send_json(self, payload: dict, status: int = 200) -> None:
        self.send_text(json.dumps(payload), status, "application/json; charset=utf-8")

    def do_GET(self) -> None:  # noqa: N802 - stdlib signature
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if path == "/healthz":
            self.send_text("ok")
            return

        if path == "/api/series":
            self.send_json({"series": discover_series(self.labs_dir)})
            return

        if path == "/api/question":
            series = query.get("series", [""])[0]
            slug = query.get("q", [""])[0]
            payload = question_payload(self.labs_dir, series, slug)
            if payload is None:
                self.send_json({"error": "question not found"}, 404)
            else:
                self.send_json(payload)
            return

        if path == "/api/config":
            self.send_json({"vncPassword": self.vnc_password, "wsPort": self.ws_port})
            return

        if path == "/api/open-docs":
            url = query.get("url", [""])[0]
            ok, message = open_in_firefox(url)
            self.send_json({"ok": ok, "message": message}, 200 if ok else 400)
            return

        self.serve_static(path)

    def do_POST(self) -> None:  # noqa: N802 - stdlib signature
        parsed = urlparse(self.path)
        if parsed.path != "/api/open-docs":
            self.send_json({"error": "not found"}, 404)
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length) if length else b"{}"
            payload = json.loads(body or b"{}")
        except (ValueError, json.JSONDecodeError):
            self.send_json({"error": "invalid JSON"}, 400)
            return
        if not isinstance(payload, dict):
            self.send_json({"error": "invalid JSON"}, 400)
            return

        ok, message = open_in_firefox(str(payload.get("url", "")))
        self.send_json({"ok": ok, "message": message}, 200 if ok else 400)

    def serve_static(self, path: str) -> None:
        if path in ("/", "/index.html"):
            file_path = self.static_dir / "index.html"
            base_dir = self.static_dir
        elif path == "/viewer.html":
            file_path = self.static_dir / "viewer.html"
            base_dir = self.static_dir
        elif path.startswith("/vendor/novnc/"):
            rel = path[len("/vendor/novnc/") :]
            file_path = self.vendor_dir / rel
            base_dir = self.vendor_dir
        elif path in ("/app.js", "/style.css"):
            file_path = self.static_dir / path.lstrip("/")
            base_dir = self.static_dir
        else:
            self.send_text("Not found", 404)
            return

        if not file_path.is_file() or not is_relative_to(file_path, base_dir):
            self.send_text("Not found", 404)
            return

        data = file_path.read_bytes()
        content_type = mimetypes.guess_type(str(file_path))[0] or "application/octet-stream"
        if content_type.startswith("text/") or content_type in ("application/javascript",):
            content_type += "; charset=utf-8"
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-cache" if file_path.suffix in (".html", ".js", ".css") else "max-age=3600")
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    parser = argparse.ArgumentParser(description="Local CKA ExamUI")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8080)
    parser.add_argument("--labs", default="/home/candidate/cka-practice-labs")
    parser.add_argument("--static", default=None)
    parser.add_argument("--vendor", default=None)
    args = parser.parse_args()

    here = Path(__file__).resolve().parent
    ExamUIHandler.labs_dir = Path(args.labs)
    ExamUIHandler.static_dir = Path(args.static) if args.static else here / "static"
    ExamUIHandler.vendor_dir = Path(args.vendor) if args.vendor else here / "vendor" / "novnc"
    ExamUIHandler.vnc_password = os.environ.get("CKA_VNC_PASSWORD", "")
    ExamUIHandler.ws_port = int(os.environ.get("CKA_VNC_WS_PORT", "6080"))

    httpd = ThreadingHTTPServer((args.host, args.port), ExamUIHandler)
    print(
        f"CKA ExamUI on http://{args.host}:{args.port}/ "
        f"(labs: {args.labs}, noVNC ws: {ExamUIHandler.ws_port})",
        flush=True,
    )
    httpd.serve_forever()


if __name__ == "__main__":
    main()
