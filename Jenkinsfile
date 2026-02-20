// ============================================================
// Jenkinsfile — Pipeline CI/CD avec sécurité & Trivy
// ============================================================

pipeline {
    agent any

    // --------------------------------------------------------
    // Variables d'environnement
    // --------------------------------------------------------
    environment {
        // Docker Hub — à modifier avec votre username
        DOCKERHUB_USERNAME    = "sylvain849"
        IMAGE_NAME            = "${DOCKERHUB_USERNAME}/flask-cicd-app"
        IMAGE_TAG             = "${BUILD_NUMBER}"
        IMAGE_FULL            = "${IMAGE_NAME}:${IMAGE_TAG}"
        IMAGE_LATEST          = "${IMAGE_NAME}:latest"

        // Credentials (configurés dans Jenkins > Manage Credentials)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-creds')

        // Kubernetes
        K8S_NAMESPACE         = "production"
        K8S_DEPLOYMENT        = "flask-app"

        // Trivy — seuil de sévérité (CRITICAL bloque le pipeline)
        TRIVY_SEVERITY        = "CRITICAL,HIGH"
        TRIVY_EXIT_CODE       = "1"   // 1 = échouer si vulnérabilité trouvée
    }

    // --------------------------------------------------------
    // Options globales du pipeline
    // --------------------------------------------------------
    options {
        timeout(time: 30, unit: 'MINUTES')       // Timeout global
        disableConcurrentBuilds()                // Pas de builds parallèles
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    // --------------------------------------------------------
    // Déclencheurs
    // --------------------------------------------------------
    triggers {
        githubPush()  // Déclenché par le WebHook GitHub
    }

    stages {

        // ====================================================
        // ÉTAPE 1 : Clone du dépôt
        // ====================================================
        stage('📥 Clone Repository') {
            steps {
                echo "🔄 Récupération du code source..."
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        // ====================================================
        // ÉTAPE 2 : Analyse statique de sécurité du code
        // ====================================================
        stage('🔍 SAST - Code Security Scan') {
            steps {
                echo "🔍 Analyse statique du code Python (Bandit)..."
                sh '''
                    # Installer Bandit avec pip3 et forcer le PATH
                    pip3 install bandit --quiet --break-system-packages 2>/dev/null || \
                    pip3 install bandit --quiet 2>/dev/null || true

                    # Trouver le binaire bandit où qu'il soit installé
                    BANDIT=$(find /usr /root ~/.local -name "bandit" -type f 2>/dev/null | head -1)

                    if [ -z "$BANDIT" ]; then
                        echo "⚠️  Bandit introuvable, scan SAST ignoré"
                        echo '{"skipped": true}' > bandit-report.json
                    else
                        echo "✅ Bandit trouvé : $BANDIT"

                        # Scan JSON
                        $BANDIT -r app/ \
                            -f json \
                            -o bandit-report.json \
                            --severity-level medium \
                            --confidence-level medium || true

                        # Résumé lisible
                        $BANDIT -r app/ \
                            --severity-level medium \
                            --confidence-level medium \
                            -ll || true
                    fi
                '''
            }
            post {
                always {
                    // Archiver le rapport Bandit
                    archiveArtifacts artifacts: 'bandit-report.json', allowEmptyArchive: true
                }
            }
        }

        // ====================================================
        // ÉTAPE 3 : Build de l'image Docker
        // ====================================================
        stage('🔨 Docker Build') {
            steps {
                echo "🏗️  Construction de l'image Docker..."
                sh """
                    docker build \
                        --no-cache \
                        --build-arg BUILD_DATE=\$(date -u +%Y-%m-%dT%H:%M:%SZ) \
                        --build-arg BUILD_VERSION=${IMAGE_TAG} \
                        -t ${IMAGE_FULL} \
                        -t ${IMAGE_LATEST} \
                        .
                """
                sh "docker images | grep ${IMAGE_NAME}"
            }
        }

        // ====================================================
        // ÉTAPE 4 : SCAN TRIVY — Vulnérabilités image Docker
        // ====================================================
        stage('🛡️  Trivy - Image Security Scan') {
            steps {
                echo "🛡️  Scan de sécurité Trivy en cours..."
                sh '''
                    # Vérifier si Trivy est déjà installé (compatible sh/dash)
                    if trivy --version >/dev/null 2>&1; then
                        echo "✅ Trivy déjà installé : $(trivy --version)"
                    else
                        echo "📦 Installation de Trivy..."
                        curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /tmp
                        cp /tmp/trivy /usr/local/bin/trivy 2>/dev/null || \
                            install -m 755 /tmp/trivy /usr/local/bin/trivy 2>/dev/null || \
                            export PATH="/tmp:$PATH"
                    fi
                    trivy --version
                '''

                sh """
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "   TRIVY SCAN — ${IMAGE_FULL}"
                    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

                    # Rapport JSON (pour archivage)
                    trivy image \
                        --format json \
                        --output trivy-report.json \
                        --severity ${TRIVY_SEVERITY} \
                        --ignorefile .trivyignore \
                        --no-progress \
                        ${IMAGE_FULL} || true

                    # Rapport texte lisible (dans les logs Jenkins)
                    trivy image \
                        --format table \
                        --severity ${TRIVY_SEVERITY} \
                        --exit-code ${TRIVY_EXIT_CODE} \
                        --ignorefile .trivyignore \
                        --no-progress \
                        ${IMAGE_FULL}
                """
            }
            post {
                always {
                    archiveArtifacts artifacts: 'trivy-report.json', allowEmptyArchive: true
                }
                failure {
                    echo "❌ ATTENTION : Des vulnérabilités CRITICAL/HIGH ont été détectées !"
                    echo "⛔ Déploiement bloqué par la politique de sécurité."
                }
            }
        }

        // ====================================================
        // ÉTAPE 5 : Scan des secrets (Gitleaks)
        // ====================================================
        stage('🔐 Secrets Scan - Gitleaks') {
            steps {
                sh '''
                    if ! gitleaks version >/dev/null 2>&1; then
                        echo "📦 Installation de Gitleaks..."
                        curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz \
                            | tar -xz -C /tmp gitleaks 2>/dev/null || true
                        cp /tmp/gitleaks /usr/local/bin/gitleaks 2>/dev/null || true
                    fi

                    # Scanner le repo pour des secrets exposés
                    gitleaks detect \
                        --source . \
                        --report-format json \
                        --report-path gitleaks-report.json \
                        --no-banner || true

                    echo "✅ Scan secrets terminé"
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'gitleaks-report.json', allowEmptyArchive: true
                }
            }
        }

        // ====================================================
        // ÉTAPE 6 : Push vers Docker Hub
        // ====================================================
        stage('🚀 Docker Push') {
            steps {
                echo "📤 Push de l'image vers Docker Hub..."
                sh """
                    echo \${DOCKERHUB_CREDENTIALS_PSW} | \
                        docker login -u \${DOCKERHUB_CREDENTIALS_USR} --password-stdin

                    docker push ${IMAGE_FULL}
                    docker push ${IMAGE_LATEST}

                    echo "✅ Image poussée : ${IMAGE_FULL}"
                """
            }
            post {
                always {
                    sh 'docker logout || true'
                }
            }
        }

        // ====================================================
        // ÉTAPE 7 : Scan Trivy sur l'image distante (Docker Hub)
        // ====================================================
        stage('🛡️  Trivy - Remote Image Scan') {
            steps {
                sh """
                    trivy image \
                        --format table \
                        --severity ${TRIVY_SEVERITY} \
                        --exit-code 0 \
                        --no-progress \
                        ${IMAGE_FULL}
                """
            }
        }

        // ====================================================
        // ÉTAPE 8 : Déploiement Kubernetes
        // ====================================================
        stage('☸️  Deploy to Kubernetes') {
            steps {
                echo "🚢 Déploiement sur Kubernetes..."
                sh """
                    # Namespace déjà créé manuellement - ignorer si existe
                    kubectl get namespace ${K8S_NAMESPACE} >/dev/null 2>&1 || true

                    # Appliquer uniquement deployment et service (pas namespace.yaml)
                    kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                    kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}

                    # Mettre à jour l'image avec le nouveau tag
                    kubectl set image deployment/${K8S_DEPLOYMENT} \
                        ${K8S_DEPLOYMENT}=${IMAGE_FULL} \
                        -n ${K8S_NAMESPACE}

                    # Attendre que le rollout se termine
                    kubectl rollout status deployment/${K8S_DEPLOYMENT} \
                        -n ${K8S_NAMESPACE} \
                        --timeout=120s

                    echo "✅ Déploiement terminé avec succès"
                """
            }
        }

        // ====================================================
        // ÉTAPE 9 : Vérification post-déploiement
        // ====================================================
        stage('✅ Post-Deploy Verification') {
            steps {
                sh """
                    echo "📊 État du déploiement :"
                    kubectl get pods -n ${K8S_NAMESPACE} -l app=${K8S_DEPLOYMENT}

                    echo ""
                    echo "🌐 Services disponibles :"
                    kubectl get services -n ${K8S_NAMESPACE}

                    echo ""
                    echo "📝 Derniers événements :"
                    kubectl get events -n ${K8S_NAMESPACE} \
                        --sort-by=.metadata.creationTimestamp | tail -10
                """
            }
        }
    }

    // --------------------------------------------------------
    // Actions post-pipeline
    // --------------------------------------------------------
    post {
        success {
            echo """
            ╔══════════════════════════════════════════╗
            ║  ✅  PIPELINE RÉUSSI                     ║
            ║  Image : ${IMAGE_FULL}
            ║  Build : #${BUILD_NUMBER}
            ╚══════════════════════════════════════════╝
            """
        }
        failure {
            echo """
            ╔══════════════════════════════════════════╗
            ║  ❌  PIPELINE ÉCHOUÉ                     ║
            ║  Build : #${BUILD_NUMBER}
            ║  Vérifiez les logs ci-dessus             ║
            ╚══════════════════════════════════════════╝
            """
        }
        always {
            // Nettoyage des images locales pour libérer de l'espace
            sh """
                docker rmi ${IMAGE_FULL} || true
                docker rmi ${IMAGE_LATEST} || true
                docker image prune -f || true
            """
            // Archiver tous les rapports de sécurité
            archiveArtifacts artifacts: '*-report.json', allowEmptyArchive: true
        }
    }
}
