FROM debian:12-slim

RUN apt-get update && apt-get install -y \
    python3 && rm -rf /var/lib/apt/lists/*

COPY tools/monitor.py /opt/monitor/monitor.py

WORKDIR /opt/monitor

EXPOSE 9090

CMD ["python3", "/opt/monitor/monitor.py"]
