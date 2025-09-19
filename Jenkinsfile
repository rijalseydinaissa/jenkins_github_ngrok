pipeline {
    agent any

    environment {
        // Variables pour ngrok
        NGROK_TOKEN = credentials('ngrok-token')
        APP_PORT = '8080'

        // Variables Docker
        DOCKER_IMAGE = "mon-app-java:${BUILD_NUMBER}"
        CONTAINER_NAME = "mon-app-container"
    }

    stages {
        stage('🔧 Environment Setup') {
            steps {
                echo '🔧 Configuration de l\'environnement...'
                script {
                    // Vérifier Docker
                    try {
                        sh 'docker --version'
                        sh 'docker ps'
                        echo '✅ Docker accessible'
                    } catch (Exception e) {
                        error '❌ Docker non accessible: ' + e.getMessage()
                    }

                    // Vérifier Java
                    try {
                        sh 'java -version'
                        echo '✅ Java accessible'
                    } catch (Exception e) {
                        echo '⚠️ Java non configuré, installation automatique...'
                        // Jenkins utilisera l'installation automatique
                    }
                }
            }
        }

        stage('📥 Checkout') {
            steps {
                echo '🔄 Récupération du code source...'

                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/main']],
                    userRemoteConfigs: [[
                        url: 'https://github.com/rijalseydinaissa/jenkins_github_ngrok.git'
                    ]],
                    extensions: [
                        [$class: 'CleanBeforeCheckout'],
                        [$class: 'CleanCheckout']
                    ]
                ])

                script {
                    try {
                        env.GIT_COMMIT_MSG = sh(
                            script: 'git log -1 --pretty=%B',
                            returnStdout: true
                        ).trim()

                        env.GIT_COMMIT_SHORT = sh(
                            script: 'git rev-parse --short HEAD',
                            returnStdout: true
                        ).trim()
                    } catch (Exception e) {
                        env.GIT_COMMIT_MSG = "Manual build"
                        env.GIT_COMMIT_SHORT = "manual"
                    }
                }
            }
        }

        stage('🔍 Code Analysis') {
            steps {
                echo '🔍 Analyse du code...'
                sh '''
                    echo "=== PROJECT STRUCTURE ==="
                    ls -la
                    echo "=== BUILD INFO ==="
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Commit: ${GIT_COMMIT_MSG}"
                    echo "Git Short: ${GIT_COMMIT_SHORT}"
                    echo "=========================="
                '''

                // Vérifier les fichiers essentiels
                script {
                    if (!fileExists('Dockerfile')) {
                        error '❌ Dockerfile manquant'
                    }
                    if (!fileExists('pom.xml')) {
                        error '❌ pom.xml manquant'
                    }
                    echo '✅ Fichiers de configuration présents'
                }
            }
        }

        stage('🐳 Docker Build') {
            steps {
                echo '🐳 Construction avec Docker...'
                script {
                    try {
                        // Nettoyage des ressources existantes
                        sh '''
                            echo "🧹 Nettoyage..."
                            docker stop ${CONTAINER_NAME} 2>/dev/null || true
                            docker rm ${CONTAINER_NAME} 2>/dev/null || true
                            docker rmi ${DOCKER_IMAGE} 2>/dev/null || true
                        '''

                        // Build avec Docker (inclut Maven)
                        echo "🔨 Construction de l'image Docker (avec build Maven intégré)..."
                        sh "docker build -t ${DOCKER_IMAGE} ."

                        // Vérifier l'image
                        sh "docker images | grep ${DOCKER_IMAGE.split(':')[0]}"

                    } catch (Exception e) {
                        error "❌ Échec du build Docker: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('🚀 Deploy Application') {
            steps {
                echo '🚀 Déploiement de l\'application...'
                script {
                    try {
                        // Démarrer le conteneur
                        sh """
                            echo "🚀 Démarrage du conteneur..."
                            docker run -d \\
                                --name ${CONTAINER_NAME} \\
                                -p ${APP_PORT}:${APP_PORT} \\
                                --restart unless-stopped \\
                                ${DOCKER_IMAGE}
                        """

                        // Vérifier le conteneur
                        sh '''
                            echo "🔍 Vérification du conteneur..."
                            docker ps | grep ${CONTAINER_NAME}
                        '''

                        // Health check robuste
                        sh '''
                            echo "⏳ Test de démarrage de l'application..."
                            timeout=120
                            interval=5

                            while [ $timeout -gt 0 ]; do
                                echo "⏳ Vérification... (${timeout}s restantes)"

                                # Essayer plusieurs endpoints
                                if curl -f -m 10 http://localhost:8080/health > /dev/null 2>&1; then
                                    echo "✅ Application prête (endpoint health)!"
                                    curl -s http://localhost:8080/health
                                    break
                                elif curl -f -m 10 http://localhost:8080/ > /dev/null 2>&1; then
                                    echo "✅ Application prête (endpoint racine)!"
                                    break
                                elif curl -f -m 10 http://localhost:8080/actuator/health > /dev/null 2>&1; then
                                    echo "✅ Application prête (actuator health)!"
                                    break
                                fi

                                # Logs de débogage si problème
                                if [ $timeout -le 60 ] && [ $((timeout % 20)) -eq 0 ]; then
                                    echo "📋 Logs du conteneur (dernières 5 lignes):"
                                    docker logs ${CONTAINER_NAME} --tail 5 2>/dev/null || true
                                fi

                                sleep $interval
                                timeout=$((timeout-interval))
                            done

                            if [ $timeout -le 0 ]; then
                                echo "❌ Timeout: Application non accessible"
                                echo "📋 Logs complets du conteneur:"
                                docker logs ${CONTAINER_NAME} 2>/dev/null || true
                                echo "📋 Statut du conteneur:"
                                docker ps -a | grep ${CONTAINER_NAME} || true
                                exit 1
                            fi
                        '''

                    } catch (Exception e) {
                        echo "❌ Erreur de déploiement: ${e.getMessage()}"
                        sh '''
                            echo "📋 Diagnostic d'erreur:"
                            docker logs ${CONTAINER_NAME} 2>/dev/null || echo "Pas de logs disponibles"
                            docker ps -a | grep ${CONTAINER_NAME} || echo "Conteneur non trouvé"
                        '''
                        throw e
                    }
                }
            }
        }

        stage('🌐 Expose with ngrok') {
            steps {
                echo '🌐 Exposition publique via ngrok...'
                script {
                    try {
                        // Nettoyage ngrok
                        sh '''
                            echo "🧹 Arrêt des processus ngrok existants..."
                            pkill ngrok 2>/dev/null || true
                            sleep 5
                        '''

                        // Configuration ngrok
                        sh '''
                            echo "🔧 Configuration ngrok..."
                            ngrok config add-authtoken $NGROK_TOKEN
                        '''

                        // Démarrage ngrok
                        sh '''
                            echo "🚀 Démarrage ngrok..."
                            nohup ngrok http 8080 --log=stdout > ngrok.log 2>&1 &
                            echo "⏳ Attente du démarrage ngrok..."
                            sleep 15
                        '''

                        // Récupération URL avec retry
                        sh '''
                            attempts=0
                            max_attempts=6

                            while [ $attempts -lt $max_attempts ]; do
                                attempts=$((attempts+1))
                                echo "🔍 Tentative $attempts/$max_attempts..."

                                # Vérifier l'API ngrok
                                if ! curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
                                    echo "⚠️ API ngrok non accessible, attente..."
                                    sleep 10
                                    continue
                                fi

                                # Récupérer l'URL
                                NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d '"' -f 4 | head -n 1)

                                if [ -n "$NGROK_URL" ]; then
                                    echo "🌐 URL publique trouvée: $NGROK_URL"

                                    # Test de l'URL
                                    if curl -f -m 30 "$NGROK_URL/" >/dev/null 2>&1; then
                                        echo "✅ URL ngrok fonctionnelle!"
                                        echo "🌐 Application accessible: $NGROK_URL"
                                        echo "🔗 Endpoints disponibles:"
                                        echo "  - Accueil: $NGROK_URL/"
                                        echo "  - Health: $NGROK_URL/health"
                                        echo "  - Hello: $NGROK_URL/hello/Jenkins"

                                        # Sauvegarder l'URL
                                        echo "$NGROK_URL" > ngrok_url.txt
                                        break
                                    else
                                        echo "⚠️ URL trouvée mais non accessible, retry..."
                                    fi
                                else
                                    echo "⚠️ URL non trouvée, retry..."
                                fi

                                sleep 10
                            done

                            if [ $attempts -eq $max_attempts ]; then
                                echo "❌ Impossible de configurer ngrok"
                                echo "📋 Logs ngrok:"
                                cat ngrok.log 2>/dev/null || echo "Pas de logs"
                                echo "📋 API ngrok:"
                                curl -s http://localhost:4040/api/tunnels 2>/dev/null || echo "API non accessible"
                                exit 1
                            fi
                        '''

                    } catch (Exception e) {
                        echo "❌ Erreur ngrok: ${e.getMessage()}"
                        sh '''
                            echo "📋 Diagnostic ngrok:"
                            cat ngrok.log 2>/dev/null || echo "Pas de logs ngrok"
                            ps aux | grep ngrok || echo "Pas de processus ngrok"
                            netstat -tlnp | grep 4040 || echo "Port 4040 non ouvert"
                        '''
                        throw e
                    }
                }
            }
        }

        stage('🧪 Integration Tests') {
            steps {
                echo '🧪 Tests d\'intégration...'
                script {
                    def ngrokUrl = ""
                    try {
                        ngrokUrl = readFile('ngrok_url.txt').trim()
                    } catch (Exception e) {
                        error "❌ URL ngrok non disponible pour les tests"
                    }

                    sh """
                        echo "🧪 Tests sur: ${ngrokUrl}"

                        echo "🧪 Test endpoint principal..."
                        curl -f -m 30 "${ngrokUrl}/" -o /dev/null -s || exit 1

                        echo "🧪 Test endpoint hello..."
                        curl -f -m 30 "${ngrokUrl}/hello/CI-CD-Test" -o /dev/null -s || exit 1

                        echo "✅ Tous les tests passés!"
                    """
                }
            }
        }
    }

    post {
        always {
            echo '🧹 Nettoyage final...'
            script {
                // Archiver les logs
                archiveArtifacts(
                    artifacts: '*.log',
                    allowEmptyArchive: true
                )

                // Mettre à jour la description du build
                try {
                    def ngrokUrl = readFile('ngrok_url.txt').trim()
                    currentBuild.description = "🌐 <a href='${ngrokUrl}'>${ngrokUrl}</a>"
                } catch (Exception e) {
                    currentBuild.description = "❌ URL non disponible"
                }
            }
        }

        success {
            echo '✅ Déploiement réussi!'
            script {
                def ngrokUrl = "Non disponible"
                try {
                    ngrokUrl = readFile('ngrok_url.txt').trim()
                } catch (Exception e) {
                    echo "⚠️ URL ngrok non récupérable"
                }

                echo """
==========================================
🎉 DÉPLOIEMENT RÉUSSI!
==========================================
🌐 URL publique: ${ngrokUrl}
📱 Endpoints:
   • Accueil: ${ngrokUrl}/
   • Health: ${ngrokUrl}/health
   • Hello: ${ngrokUrl}/hello/World
💼 Build: #${BUILD_NUMBER}
📝 Commit: ${env.GIT_COMMIT_SHORT} - ${env.GIT_COMMIT_MSG}
==========================================
                """
            }
        }

        failure {
            echo '❌ Déploiement échoué'
            script {
                sh '''
                    echo "=== DIAGNOSTIC D'ÉCHEC ==="
                    echo "Conteneurs Docker:"
                    docker ps -a || true
                    echo "Images Docker:"
                    docker images || true
                    echo "Processus:"
                    ps aux | grep -E "(java|ngrok)" || true
                    echo "Ports ouverts:"
                    netstat -tlnp | grep -E "(8080|4040)" || true
                    echo "=========================="
                '''
            }
        }
    }
}