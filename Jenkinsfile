pipeline {
    agent any

    tools {
        maven 'Maven-3.9.0'
        jdk 'JDK-21'
    }

    environment {
        GITHUB_CREDENTIALS = 'github-credentials'
        APP_NAME = 'my-java-app'
        APP_PORT = '8080'
        NGROK_PORT = '8080'
    }

    stages {
        stage('🔍 Checkout') {
            steps {
                echo '📥 Récupération du code source...'
                checkout scm
            }
        }

        stage('🧹 Clean') {
            steps {
                echo '🧹 Nettoyage du workspace...'
                sh 'mvn clean'
            }
        }

        stage('📦 Compile') {
            steps {
                echo '⚙️ Compilation du projet...'
                sh 'mvn compile'
            }
        }

        stage('🧪 Test') {
            steps {
                echo '🧪 Exécution des tests...'
                sh 'mvn test'
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('📦 Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
            }
        }

        stage('🛑 Stop Previous Deployment') {
            steps {
                echo '🛑 Arrêt de la précédente instance...'
                script {
                    sh '''
                        # Tuer les processus Java précédents
                        pkill -f "java.*my-java-app" || true
                        # Tuer ngrok précédent
                        pkill ngrok || true
                        sleep 5
                    '''
                }
            }
        }

        stage('🚀 Deploy') {
            steps {
                echo '🚀 Déploiement de l\'application...'
                script {
                    sh '''
                        # Rendre le script exécutable
                        chmod +x scripts/deploy.sh scripts/start-ngrok.sh

                        # Lancer le déploiement
                        ./scripts/deploy.sh

                        # Attendre que l'application démarre
                        sleep 15

                        # Lancer ngrok
                        ./scripts/start-ngrok.sh

                        # Attendre que ngrok se connecte
                        sleep 10
                    '''
                }
            }
        }

        stage('✅ Health Check') {
            steps {
                echo '✅ Vérification de la santé de l\'application...'
                script {
                    sh '''
                        # Test local
                        curl -f http://localhost:8080/health || exit 1

                        # Récupérer l'URL ngrok
                        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
data = json.load(sys.stdin)
for tunnel in data['tunnels']:
    if tunnel['proto'] == 'https':
        print(tunnel['public_url'])
        break
" 2>/dev/null || echo "URL ngrok non disponible")

                        echo "🌐 Application disponible localement : http://localhost:8080"
                        echo "🌍 Application disponible publiquement : $NGROK_URL"

                        # Test de l'URL publique si disponible
                        if [ "$NGROK_URL" != "URL ngrok non disponible" ]; then
                            curl -f "$NGROK_URL/health" || echo "⚠️  URL publique non accessible immédiatement"
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '📊 Archivage des artefacts...'
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

            echo '🧹 Nettoyage...'
            cleanWs()
        }
        success {
            echo '✅ Pipeline exécuté avec succès !'
        }
        failure {
            echo '❌ Échec du pipeline'
        }
    }
}