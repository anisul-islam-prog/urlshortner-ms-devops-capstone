# ─── Build Stage ───
FROM python:3.12.13-alpine AS builder
WORKDIR /build

RUN apk upgrade --no-cache && \
    apk add --no-cache gcc musl-dev linux-headers

COPY python-service/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt
RUN pip install --no-cache-dir --user gunicorn

# ─── Runtime Stage ───
FROM python:3.12.13-alpine
WORKDIR /app

# Patch OS packages
RUN apk upgrade --no-cache

# Create non-root user (Alpine syntax)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

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