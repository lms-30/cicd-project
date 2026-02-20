# ============================================================
# Stage 1 : Builder — installe les dépendances
# ============================================================
FROM python:3.12-slim AS builder

# Répertoire de travail
WORKDIR /app

# Copie uniquement le fichier de dépendances d'abord (cache Docker)
COPY requirements.txt .

# Installation des dépendances dans un dossier séparé (pas de root)
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ============================================================
# Stage 2 : Runtime — image minimale et sécurisée
# ============================================================
FROM python:3.12-slim AS runtime

# Métadonnées
LABEL maintainer="votre-email@exemple.com"
LABEL version="1.0.0"
LABEL description="Application Flask CI/CD sécurisée"

# Variables d'environnement de sécurité
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_ENV=production \
    APP_VERSION=1.0.0

# Créer un utilisateur non-root (bonne pratique sécurité)
RUN groupadd --gid 1001 appgroup \
    && useradd --uid 1001 --gid appgroup --shell /bin/bash --create-home appuser

WORKDIR /app

# Copier les dépendances depuis le stage builder
COPY --from=builder /install /usr/local

# Copier le code de l'application
COPY app/ .

# Donner les droits à l'utilisateur non-root
RUN chown -R appuser:appgroup /app

# Basculer vers l'utilisateur non-root
USER appuser

# Exposer le port (documentation uniquement)
EXPOSE 5000

# Healthcheck intégré dans l'image
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Démarrer avec Gunicorn (production-grade, jamais flask run)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "60", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
