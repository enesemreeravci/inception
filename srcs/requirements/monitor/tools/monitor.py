#!/usr/bin/env python3

import json
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SERVICES = {
    "mariadb": ("mariadb", 3306),
    "redis": ("redis", 6379),
    "wordpress": ("wordpress", 9000),
    "adminer": ("adminer", 8080),
    "ftp": ("ftp", 21),
    "static-site": ("static-site", 80),
    "nginx": ("nginx", 443),
}


def check_service(host, port):
    try:
        with socket.create_connection((host, port), timeout=2):
            return "up"
    except OSError:
        return "down"


def health_report():
    services = {
        name: check_service(host, port)
        for name, (host, port) in SERVICES.items()
    }

    healthy = all(status == "up" for status in services.values())

    return {
        "status": "healthy" if healthy else "degraded",
        "services": services,
    }


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health"):
            self.send_error(404, "Not Found")
            return

        report = health_report()
        body = json.dumps(report, indent=2).encode("utf-8")

        self.send_response(200 if report["status"] == "healthy" else 503)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format_string, *args):
        print(f"[monitor] {format_string % args}")


server = ThreadingHTTPServer(("0.0.0.0", 9090), HealthHandler)

print("[monitor] health service listening on port 9090", flush=True)
server.serve_forever()
