# ============================================================
# Stage 1 : Builder — installe les dépendances
# ============================================================
# Flask, Gunicorn, Werkzeug sont du pur Python — pas besoin de gcc !
FROM python:3.12-alpine AS builder

WORKDIR /app

COPY requirements.txt .

# Pas de gcc nécessaire — toutes les dépendances ont des wheels précompilés
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================
# Stage 2 : Runtime — image minimale Alpine sécurisée
# ============================================================
FROM python:3.12-alpine AS runtime

LABEL maintainer="votre-email@exemple.com"
LABEL version="1.0.0"
LABEL description="Application Flask CI/CD sécurisée - Alpine"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    APP_VERSION=1.0.0

# Sur Alpine : addgroup/adduser (pas groupadd/useradd)
RUN addgroup -g 1001 appgroup \
    && adduser -u 1001 -G appgroup -s /bin/sh -D appuser

WORKDIR /app

COPY --from=builder /install /usr/local
COPY app/ .

RUN chown -R appuser:appgroup /app

USER appuser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", \
     "--access-logfile", "-", "--error-logfile", "-", "app:app"]
