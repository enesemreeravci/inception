#!/usr/bin/env python3

import json
import socket
from datetime import datetime
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


def build_dashboard(report):
    cards = ""

    for name, status in report["services"].items():
        host, port = SERVICES[name]

        cards += f"""
        <div class="service-card {status}">
            <div class="service-header">
                <h2>{name}</h2>
                <span class="status-dot"></span>
            </div>

            <p class="status-text">{status.upper()}</p>

            <div class="service-info">
                <span>Host: {host}</span>
                <span>Port: {port}</span>
            </div>
        </div>
        """

    healthy_count = sum(
        1
        for status in report["services"].values()
        if status == "up"
    )

    total_count = len(report["services"])

    checked_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    return f"""
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta
        name="viewport"
        content="width=device-width, initial-scale=1.0"
    >

    <meta http-equiv="refresh" content="5">

    <title>Inception Monitor</title>

    <style>
        * {{
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }}

        body {{
            font-family: Arial, sans-serif;
            background: #111827;
            color: #f9fafb;
            min-height: 100vh;
        }}

        .container {{
            width: 90%;
            max-width: 1200px;
            margin: 0 auto;
            padding: 50px 0;
        }}

        .title {{
            margin-bottom: 30px;
        }}

        .title h1 {{
            font-size: 36px;
            margin-bottom: 8px;
        }}

        .title p {{
            color: #9ca3af;
        }}

        .system-status {{
            padding: 25px;
            border-radius: 12px;
            margin-bottom: 30px;
        }}

        .system-status.healthy {{
            background: #064e3b;
            border: 1px solid #10b981;
        }}

        .system-status.degraded {{
            background: #7f1d1d;
            border: 1px solid #ef4444;
        }}

        .system-status h2 {{
            margin-bottom: 8px;
        }}

        .system-status p {{
            color: #d1d5db;
        }}

        .services-grid {{
            display: grid;
            grid-template-columns:
                repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
        }}

        .service-card {{
            background: #1f2937;
            padding: 25px;
            border-radius: 12px;
            border: 1px solid #374151;
            transition: transform 0.2s ease;
        }}

        .service-card:hover {{
            transform: translateY(-3px);
        }}

        .service-card.up {{
            border-left: 5px solid #10b981;
        }}

        .service-card.down {{
            border-left: 5px solid #ef4444;
        }}

        .service-header {{
            display: flex;
            align-items: center;
            justify-content: space-between;
            margin-bottom: 20px;
        }}

        .service-header h2 {{
            text-transform: capitalize;
            font-size: 22px;
        }}

        .status-dot {{
            width: 12px;
            height: 12px;
            border-radius: 50%;
        }}

        .up .status-dot {{
            background: #10b981;
            box-shadow: 0 0 8px #10b981;
        }}

        .down .status-dot {{
            background: #ef4444;
            box-shadow: 0 0 8px #ef4444;
        }}

        .status-text {{
            font-weight: bold;
            margin-bottom: 15px;
        }}

        .up .status-text {{
            color: #34d399;
        }}

        .down .status-text {{
            color: #f87171;
        }}

        .service-info {{
            display: flex;
            flex-direction: column;
            gap: 5px;
            color: #9ca3af;
            font-size: 14px;
        }}

        .footer {{
            margin-top: 35px;
            color: #6b7280;
            font-size: 14px;
        }}
    </style>
</head>

<body>

    <main class="container">

        <section class="title">
            <h1>Inception Service Monitor</h1>
            <p>Docker infrastructure health dashboard</p>
        </section>

        <section class="system-status {report["status"]}">
            <h2>
                System {report["status"].upper()}
            </h2>

            <p>
                {healthy_count} / {total_count}
                services are online
            </p>
        </section>

        <section class="services-grid">
            {cards}
        </section>

        <div class="footer">
            Last checked: {checked_at}
            · Auto refresh every 5 seconds
        </div>

    </main>

</body>

</html>
"""


class HealthHandler(BaseHTTPRequestHandler):

    def do_GET(self):

        if self.path == "/health":
            self.handle_health()

        elif self.path == "/":
            self.handle_dashboard()

        else:
            self.send_error(404, "Not Found")


    def handle_health(self):
        report = health_report()

        body = json.dumps(
            report,
            indent=2
        ).encode("utf-8")

        status_code = (
            200
            if report["status"] == "healthy"
            else 503
        )

        self.send_response(status_code)

        self.send_header(
            "Content-Type",
            "application/json"
        )

        self.send_header(
            "Content-Length",
            str(len(body))
        )

        self.end_headers()

        self.wfile.write(body)


    def handle_dashboard(self):
        report = health_report()

        html = build_dashboard(report)

        body = html.encode("utf-8")

        self.send_response(200)

        self.send_header(
            "Content-Type",
            "text/html; charset=utf-8"
        )

        self.send_header(
            "Content-Length",
            str(len(body))
        )

        self.end_headers()

        self.wfile.write(body)


    def log_message(self, format_string, *args):
        print(
            f"[monitor] {format_string % args}"
        )


server = ThreadingHTTPServer(
    ("0.0.0.0", 9090),
    HealthHandler
)

print(
    "[monitor] health service listening on port 9090",
    flush=True
)

server.serve_forever()