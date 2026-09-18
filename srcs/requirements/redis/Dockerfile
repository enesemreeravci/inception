FROM debian:12-slim

RUN apt-get update && apt-get install -y redis-server && rm -rf /var/lib/apt/lists/*

EXPOSE 6379

CMD ["redis-server", "--bind", "0.0.0.0", "--protected-mode", "no"]
