# ─── Build Stage ───
FROM python:3.12-slim AS builder
WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY python-service/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt
RUN pip install --no-cache-dir --user gunicorn

# ─── Runtime Stage ───
FROM python:3.12-slim
WORKDIR /app

# Create user WITH home directory (-m flag)
RUN groupadd -r appgroup && useradd -m -r -g appgroup appuser

COPY --from=builder /root/.local /home/appuser/.local
COPY python-service/ .

RUN chown -R appuser:appgroup /app /home/appuser
USER appuser

ENV PATH=/home/appuser/.local/bin:$PATH
ENV HOME=/home/appuser
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=app.py
EXPOSE 5000

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--threads", "2", "app:app"]