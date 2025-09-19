pipeline {
    agent any

    environment {
        // Configuration Java et Maven
        JAVA_HOME = tool 'JDK-21'
        MAVEN_HOME = tool 'Maven-3.9.0'
        PATH = "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${env.PATH}"

        // Variables pour ngrok
        NGROK_TOKEN = credentials('ngrok-token')
        APP_PORT = '8080'
    }

    tools {
        jdk 'JDK-21'
        maven 'Maven-3.9.0'
    }

    stages {
        stage('📥 Checkout') {
            steps {
                echo '🔄 Récupération du code source...'
                checkout scm
                script {
                    try {
                        env.GIT_COMMIT_MSG = sh(
                            script: 'git log -1 --pretty=%B',
                            returnStdout: true
                        ).trim()
                    } catch (Exception e) {
                        env.GIT_COMMIT_MSG = "Manual build"
                    }
                }
            }
        }

        stage('🔍 Analyse Environnement') {
            steps {
                echo '🔍 Vérification de l\'environnement...'
                sh '''
                    echo "=== ENVIRONMENT CHECK ==="
                    echo "Java Version:"
                    java -version
                    echo "JAVA_HOME: $JAVA_HOME"
                    echo "Maven Version:"
                    mvn -version
                    echo "Git Version:"
                    git --version
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Commit: ${GIT_COMMIT_MSG}"
                    echo "Workspace: ${WORKSPACE}"
                    echo "=========================="
                '''
            }
        }

        stage('🧹 Clean') {
            steps {
                echo '🧹 Nettoyage...'
                sh 'mvn clean'
            }
        }

        stage('🔧 Compile') {
            steps {
                echo '🔧 Compilation...'
                sh 'mvn compile -Dmaven.compiler.source=21 -Dmaven.compiler.target=21'
            }
        }

        stage('🧪 Tests') {
            steps {
                echo '🧪 Exécution des tests...'
                sh 'mvn test'
            }
            post {
                always {
                    // Publier les résultats de tests s'ils existent
                    publishTestResults testResultsPattern: 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('📦 Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('🚀 Deploy Local (Java)') {
            steps {
                echo '🚀 Déploiement local avec Java...'
                script {
                    // Arrêter l'application précédente si elle existe
                    sh '''
                        # Tuer les processus Java existants sur le port 8080
                        pkill -f "mon-app-java" || true
                        sleep 5

                        # Vérifier que le port est libre
                        if lsof -ti:8080 > /dev/null 2>&1; then
                            echo "Port 8080 encore utilisé, arrêt forcé..."
                            kill -9 $(lsof -ti:8080) || true
                            sleep 5
                        fi
                    '''

                    // Démarrer l'application
                    sh '''
                        echo "🚀 Démarrage de l'application..."
                        cd target
                        JAR_FILE=$(ls *.jar | grep -v original | head -1)
                        echo "Fichier JAR: $JAR_FILE"

                        # Démarrer l'application en arrière-plan
                        nohup java -jar "$JAR_FILE" --server.port=8080 > ../app.log 2>&1 &

                        # Sauvegarder le PID
                        echo $! > ../app.pid
                        echo "Application démarrée avec PID: $(cat ../app.pid)"
                    '''

                    // Health check
                    sh '''
                        echo "⏳ Attente du démarrage de l'application..."
                        timeout=120
                        interval=5

                        while [ $timeout -gt 0 ]; do
                            echo "⏳ Vérification... ($timeout secondes restantes)"

                            # Tester différents endpoints
                            if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
                                echo "✅ Application prête (endpoint health)!"
                                curl -s http://localhost:8080/health
                                break
                            elif curl -f -s http://localhost:8080/ > /dev/null 2>&1; then
                                echo "✅ Application prête (endpoint racine)!"
                                break
                            elif curl -f -s http://localhost:8080/actuator/health > /dev/null 2>&1; then
                                echo "✅ Application prête (actuator health)!"
                                break
                            fi

                            # Afficher les logs en cas de problème
                            if [ $timeout -le 60 ] && [ $((timeout % 20)) -eq 0 ]; then
                                echo "📋 Dernières lignes des logs:"
                                tail -5 app.log 2>/dev/null || echo "Pas de logs disponibles"
                            fi

                            sleep $interval
                            timeout=$((timeout-interval))
                        done

                        if [ $timeout -le 0 ]; then
                            echo "❌ Timeout: Application non accessible"
                            echo "📋 Logs complets:"
                            cat app.log 2>/dev/null || echo "Pas de logs"
                            echo "📋 Processus:"
                            ps aux | grep java || true
                            exit 1
                        fi
                    '''
                }
            }
        }

        stage('🌐 Expose via ngrok') {
            steps {
                echo '🌐 Exposition via ngrok...'
                script {
                    sh '''
                        echo "🧹 Nettoyage ngrok..."
                        pkill ngrok || true
                        sleep 5
                    '''

                    sh '''
                        echo "🔧 Configuration ngrok..."
                        ngrok config add-authtoken $NGROK_TOKEN
                    '''

                    sh '''
                        echo "🚀 Démarrage ngrok..."
                        nohup ngrok http 8080 --log=stdout > ngrok.log 2>&1 &
                        sleep 15
                    '''

                    sh '''
                        echo "🔍 Récupération de l'URL ngrok..."
                        attempts=0
                        max_attempts=6

                        while [ $attempts -lt $max_attempts ]; do
                            attempts=$((attempts+1))
                            echo "🔍 Tentative $attempts/$max_attempts..."

                            if ! curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
                                echo "⚠️ API ngrok non accessible, attente..."
                                sleep 10
                                continue
                            fi

                            NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | cut -d '"' -f 4 | head -n 1)

                            if [ -n "$NGROK_URL" ]; then
                                echo "🌐 URL publique trouvée: $NGROK_URL"

                                if curl -f -m 30 "$NGROK_URL/" >/dev/null 2>&1; then
                                    echo "✅ URL ngrok fonctionnelle!"
                                    echo "🌐 Application accessible: $NGROK_URL"
                                    echo "🔗 Endpoints disponibles:"
                                    echo "  - Accueil: $NGROK_URL/"
                                    echo "  - Health: $NGROK_URL/health"
                                    echo "  - Hello: $NGROK_URL/hello/Jenkins"

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
                            exit 1
                        fi
                    '''
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
                archiveArtifacts artifacts: '*.log, *.pid', allowEmptyArchive: true

                // Ne pas nettoyer le workspace pour garder l'app en cours
                // cleanWs()
            }
        }

        success {
            echo '✅ Pipeline exécuté avec succès!'
            script {
                def ngrokUrl = "Non disponible"
                try {
                    ngrokUrl = readFile('ngrok_url.txt').trim()
                } catch (Exception e) {
                    echo "⚠️ URL ngrok non récupérable"
                }

                currentBuild.description = "🌐 <a href='${ngrokUrl}'>${ngrokUrl}</a>"

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
📝 Commit: ${env.GIT_COMMIT_MSG}
==========================================
                """
            }
        }

        failure {
            echo '❌ Échec du pipeline'
            script {
                sh '''
                    echo "=== DIAGNOSTIC D'ÉCHEC ==="
                    echo "Processus Java:"
                    ps aux | grep java || true
                    echo "Ports ouverts:"
                    netstat -tlnp | grep -E "(8080|4040)" || true
                    echo "Logs application:"
                    tail -20 app.log 2>/dev/null || echo "Pas de logs app"
                    echo "Logs ngrok:"
                    tail -20 ngrok.log 2>/dev/null || echo "Pas de logs ngrok"
                    echo "=========================="
                '''
            }
        }
    }
}
