# 🚀 CI/CD Pipeline Sécurisé — Flask + Jenkins + Kubernetes

Architecture complète de déploiement automatisé avec scans de sécurité Trivy.

```
git push → GitHub → WebHook → Jenkins → Trivy Scan → Docker Hub → Kubernetes
```

---

## 📁 Structure du projet

```
cicd-project/
├── app/
│   └── app.py              # Application Flask
├── k8s/
│   ├── namespace.yaml      # Namespace + quotas
│   ├── deployment.yaml     # Déploiement sécurisé
│   └── service.yaml        # Service + NetworkPolicy
├── scripts/
│   └── setup.sh            # Script de configuration initiale
├── Dockerfile              # Multi-stage build sécurisé
├── Jenkinsfile             # Pipeline CI/CD complet
├── requirements.txt
└── README.md
```

---

## ⚡ Démarrage rapide

### 1. Cloner et configurer

```bash
git clone https://github.com/VOTRE_USERNAME/cicd-project.git
cd cicd-project

# Rendre le script exécutable
chmod +x scripts/setup.sh

# Lancer la configuration automatique
./scripts/setup.sh
```

### 2. Modifier votre username Docker Hub

Dans `Jenkinsfile` :
```groovy
DOCKERHUB_USERNAME = "votre_username"   // ← Remplacer ici
```

Dans `k8s/deployment.yaml` :
```yaml
image: votre_username/flask-cicd-app:latest   // ← Remplacer ici
```

### 3. Démarrer Jenkins (si pas déjà fait)

```bash
docker run -d \
  --name jenkins \
  -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts
```

---

## 🔐 Sécurité — Ce qui est implémenté

### Docker
| Mesure | Description |
|--------|-------------|
| Multi-stage build | Image minimale, sans outils de build |
| Utilisateur non-root | UID 1001, jamais root |
| Gunicorn | Serveur WSGI de production |
| HEALTHCHECK | Surveillance intégrée |

### Kubernetes
| Mesure | Description |
|--------|-------------|
| SecurityContext | runAsNonRoot, readOnlyRootFilesystem |
| Capabilities drop ALL | Aucune capability Linux |
| NetworkPolicy | Isolation réseau des pods |
| ResourceQuota | Limites CPU/mémoire |
| Probes | Liveness, Readiness, Startup |
| automountServiceAccountToken: false | Pas d'accès API K8s |

### Pipeline Jenkins
| Étape | Outil | But |
|-------|-------|-----|
| SAST | Bandit | Vulnérabilités dans le code Python |
| Image Scan | Trivy | CVE dans les packages de l'image |
| Secrets Scan | Gitleaks | Secrets exposés dans le code |
| Remote Scan | Trivy | Vérification post-push Docker Hub |

---

## ⚙️ Configuration Jenkins

### Ajouter le credential Docker Hub
1. `Manage Jenkins` → `Credentials` → `Global` → `Add Credentials`
2. Kind : **Username with password**
3. ID : `dockerhub-creds`
4. Entrez votre username et mot de passe Docker Hub

### Créer le Pipeline
1. `New Item` → `Pipeline`
2. `Pipeline script from SCM` → `Git`
3. URL : `https://github.com/VOTRE_USERNAME/cicd-project.git`
4. Branch : `*/main`
5. Script Path : `Jenkinsfile`

### Configurer le WebHook GitHub
Dans votre repo GitHub → `Settings` → `Webhooks` → `Add webhook` :
```
Payload URL : http://VOTRE_IP_JENKINS:8080/github-webhook/
Content type : application/json
Trigger      : Just the push event
```

> 💡 Si Jenkins est en local, utilisez `ngrok http 8080` pour obtenir une URL publique.

---

## 🧪 Test local

```bash
# Build local
docker build -t flask-cicd-app:test .

# Scan Trivy local
trivy image --severity CRITICAL,HIGH flask-cicd-app:test

# Lancer l'application
docker run -p 5000:5000 flask-cicd-app:test

# Tester les endpoints
curl http://localhost:5000/
curl http://localhost:5000/health
curl http://localhost:5000/api/items
```

---

## ☸️ Commandes Kubernetes utiles

```bash
# Voir les pods
kubectl get pods -n production

# Voir les logs
kubectl logs -f deployment/flask-app -n production

# Accéder à l'application
minikube service flask-app-service -n production

# Dashboard Minikube
minikube dashboard
```

---

## 🔄 Flux complet du pipeline

```
1. 📥 Clone           → Récupération du code GitHub
2. 🔍 SAST Bandit     → Analyse statique du code Python
3. 🔨 Docker Build    → Construction image multi-stage
4. 🛡️  Trivy Local    → Scan CVE image locale (bloque si CRITICAL)
5. 🔐 Gitleaks        → Scan des secrets dans le code
6. 🚀 Docker Push     → Push vers Docker Hub
7. 🛡️  Trivy Remote   → Scan image sur Docker Hub
8. ☸️  K8s Deploy     → kubectl apply + rolling update
9. ✅ Vérification    → Contrôle de santé post-déploiement
```
