#!/bin/bash
# ============================================================
# setup.sh — Configuration initiale de l'environnement CI/CD
# ============================================================

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🚀 Setup CI/CD — Flask + Jenkins + K8s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --------------------------------------------------------
# 1. Vérifications préalables
# --------------------------------------------------------
echo ""
echo "📋 Vérification des prérequis..."

check_cmd() {
    if command -v "$1" &>/dev/null; then
        echo "  ✅ $1 trouvé"
    else
        echo "  ❌ $1 non trouvé — veuillez l'installer"
        exit 1
    fi
}

check_cmd docker
check_cmd kubectl
check_cmd minikube

# --------------------------------------------------------
# 2. Démarrer Minikube si pas déjà actif
# --------------------------------------------------------
echo ""
echo "☸️  Vérification de Minikube..."
if ! minikube status | grep -q "Running"; then
    echo "  Démarrage de Minikube..."
    minikube start --driver=docker --memory=3072 --cpus=2
fi
echo "  ✅ Minikube opérationnel"

# --------------------------------------------------------
# 3. Installer Trivy
# --------------------------------------------------------
echo ""
echo "🛡️  Installation de Trivy..."
if ! command -v trivy &>/dev/null; then
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
        | sh -s -- -b /usr/local/bin
    echo "  ✅ Trivy installé : $(trivy --version)"
else
    echo "  ✅ Trivy déjà installé : $(trivy --version)"
fi

# --------------------------------------------------------
# 4. Créer les namespaces Kubernetes
# --------------------------------------------------------
echo ""
echo "🏗️  Création du namespace Kubernetes..."
kubectl apply -f k8s/namespace.yaml
echo "  ✅ Namespace 'production' créé"

# --------------------------------------------------------
# 5. Donner accès à kubectl depuis Jenkins
# --------------------------------------------------------
echo ""
echo "🔑 Configuration de l'accès kubectl pour Jenkins..."

# Copier le kubeconfig dans le volume Jenkins
JENKINS_CONTAINER=$(docker ps --format "{{.Names}}" | grep jenkins | head -1)

if [ -n "$JENKINS_CONTAINER" ]; then
    echo "  Conteneur Jenkins trouvé : $JENKINS_CONTAINER"

    # Copier le kubeconfig
    docker exec -u root "$JENKINS_CONTAINER" mkdir -p /root/.kube
    docker cp ~/.kube/config "$JENKINS_CONTAINER":/root/.kube/config
    docker exec -u root "$JENKINS_CONTAINER" chmod 644 /root/.kube/config

    # Installer kubectl dans Jenkins
    docker exec -u root "$JENKINS_CONTAINER" bash -c "
        if ! command -v kubectl &>/dev/null; then
            curl -LO https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl
            install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        fi
    "

    # Installer Trivy dans Jenkins
    docker exec -u root "$JENKINS_CONTAINER" bash -c "
        if ! command -v trivy &>/dev/null; then
            curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
                | sh -s -- -b /usr/local/bin
        fi
    "

    # Donner accès à Docker socket
    docker exec -u root "$JENKINS_CONTAINER" chmod 666 /var/run/docker.sock

    echo "  ✅ Jenkins configuré avec kubectl, trivy et accès Docker"
else
    echo "  ⚠️  Aucun conteneur Jenkins trouvé. Vérifiez que Jenkins est démarré."
    echo "  Commande pour démarrer Jenkins :"
    echo ""
    echo "  docker run -d \\"
    echo "    --name jenkins \\"
    echo "    -p 8080:8080 -p 50000:50000 \\"
    echo "    -v jenkins_home:/var/jenkins_home \\"
    echo "    -v /var/run/docker.sock:/var/run/docker.sock \\"
    echo "    -v \$(which kubectl):/usr/local/bin/kubectl \\"
    echo "    -v \$HOME/.kube:/root/.kube \\"
    echo "    jenkins/jenkins:lts"
fi

# --------------------------------------------------------
# 6. Résumé final
# --------------------------------------------------------
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   ✅ Setup terminé !"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📌 Prochaines étapes :"
echo "  1. Éditez Jenkinsfile : remplacez 'votre_username' par votre username Docker Hub"
echo "  2. Éditez k8s/deployment.yaml : remplacez l'image par votre username"
echo "  3. Dans Jenkins : ajoutez le credential 'dockerhub-creds'"
echo "  4. Dans Jenkins : créez un pipeline pointant vers votre repo GitHub"
echo "  5. Dans GitHub : configurez le WebHook → http://VOTRE_IP:8080/github-webhook/"
echo ""
echo "🌐 Jenkins UI : http://localhost:8080"
echo "☸️  Minikube dashboard : minikube dashboard"
echo ""
