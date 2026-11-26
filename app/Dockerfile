FROM python:3.12-slim

# Run as an unprivileged user, never as root
RUN useradd --uid 10001 --no-create-home --shell /usr/sbin/nologin appuser

# Patch: libzstd1 is vulnerable in the base image and a fixed version is available.
# Remove this once the upstream python image ships the fix.
RUN apt-get update \
    && apt-get install -y --only-upgrade libzstd1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY app.py .

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080')"

CMD ["python", "app.py"]