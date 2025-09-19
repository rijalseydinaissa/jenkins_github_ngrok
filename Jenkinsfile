pipeline {
    agent any

    tools {
        maven 'Maven-3.8'
        jdk 'JDK-17'
    }

    environment {
        GITHUB_CREDENTIALS = 'github-credentials'
        APP_NAME = 'my-java-app'
        APP_PORT = '8080'
        NGROK_PORT = '8080'
        DOCKER_IMAGE = 'my-java-app:latest'
        USE_DOCKER = 'false' // Changer à 'true' pour utiliser Docker
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
                echo '🧪 Exécution des tests unitaires...'
                sh 'mvn test -Dmaven.test.failure.ignore=false'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: '**/target/surefire-reports/*.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'target/surefire-reports',
                        reportFiles: '*.html',
                        reportName: 'Test Report'
                    ])
                }
            }
        }

        stage('📦 Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
            }
        }

        stage('🐳 Docker Build') {
            when {
                environment name: 'USE_DOCKER', value: 'true'
            }
            steps {
                echo '🐳 Construction de l\'image Docker...'
                script {
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('🛑 Stop Previous Deployment') {
            steps {
                echo '🛑 Arrêt de la précédente instance...'
                script {
                    if (env.USE_DOCKER == 'true') {
                        sh '''
                            # Arrêter et supprimer les conteneurs Docker existants
                            docker stop my-java-app-container || true
                            docker rm my-java-app-container || true

                            # Tuer ngrok précédent
                            pkill ngrok || true
                            sleep 5
                        '''
                    } else {
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
        }

        stage('🚀 Deploy') {
            steps {
                echo '🚀 Déploiement de l\'application...'
                script {
                    if (env.USE_DOCKER == 'true') {
                        sh '''
                            # Déploiement avec Docker
                            docker run -d --name my-java-app-container -p 8080:8080 ${DOCKER_IMAGE}

                            # Attendre que le conteneur démarre
                            sleep 20
                        '''
                    } else {
                        sh '''
                            # Déploiement traditionnel
                            chmod +x scripts/deploy.sh scripts/start-ngrok.sh
                            ./scripts/deploy.sh
                            sleep 15
                        '''
                    }

                    // Lancer ngrok dans tous les cas
                    sh '''
                        ./scripts/start-ngrok.sh
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
            archiveArtifacts artifacts: 'target/*.jar', fingerprint: true, allowEmptyArchive: true

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