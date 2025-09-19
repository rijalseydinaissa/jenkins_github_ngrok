pipeline {
    agent any

    environment {
        // Configuration Java et Maven
        JAVA_HOME = tool 'JDK-21'
        MAVEN_HOME = tool 'Maven-3.9.0' //la version de maven doit etre la meme dans les conf de jenkins
        PATH = "${JAVA_HOME}/bin:${MAVEN_HOME}/bin:${env.PATH}"

        // Variables pour ngrok
        NGROK_TOKEN = credentials('ngrok-token')
        APP_PORT = '8080'

        // Variables Docker
        DOCKER_IMAGE = "mon-app-java:${BUILD_NUMBER}"
        CONTAINER_NAME = "mon-app-container"
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
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('🔍 Analyse Environnement') {
            steps {
                echo '🔍 Vérification de l\'environnement...'
                script {
                    def javaVersion = sh(
                        script: 'java -version 2>&1 | head -n 1',
                        returnStdout: true
                    ).trim()

                    if (!javaVersion.contains('21')) {
                        error("❌ Java 21 requis, trouvé: ${javaVersion}")
                    }
                }
                sh '''
                    echo "Java Version:"
                    java -version
                    echo "JAVA_HOME: $JAVA_HOME"
                    echo "Maven Version:"
                    mvn -version
                    echo "Git Version:"
                    git --version
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Commit: ${GIT_COMMIT_MSG}"
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

        stage('📦 Package') {
            steps {
                echo '📦 Création du package...'
                sh 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('🐳 Docker Build') {
            steps {
                echo '🐳 Construction de l\'image Docker...'
                script {
                    sh '''
                        docker stop ${CONTAINER_NAME} || true
                        docker rm ${CONTAINER_NAME} || true
                        docker rmi ${DOCKER_IMAGE} || true
                    '''
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('🚀 Deploy Local') {
            steps {
                echo '🚀 Déploiement local...'
                script {
                    sh """
                        docker run -d \
                            --name ${CONTAINER_NAME} \
                            -p ${APP_PORT}:${APP_PORT} \
                            -e SPRING_PROFILES_ACTIVE=prod \
                            ${DOCKER_IMAGE}
                    """

                    sh '''
                        echo "⏳ Attente du démarrage de l'application..."
                        timeout=60
                        while [ $timeout -gt 0 ]; do
                            if curl -f http://localhost:8080/health > /dev/null 2>&1; then
                                echo "✅ Application démarrée avec succès!"
                                break
                            fi
                            echo "⏳ En attente... ($timeout secondes restantes)"
                            sleep 5
                            timeout=$((timeout-5))
                        done

                        if [ $timeout -le 0 ]; then
                            echo "❌ Timeout: L'application n'a pas démarré dans les temps"
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
                    sh 'pkill ngrok || true'
                    sh 'ngrok config add-authtoken $NGROK_TOKEN'
                    sh 'nohup ngrok http 8080 --log=stdout > ngrok.log 2>&1 &'

                    sh '''
                        echo "⏳ Démarrage de ngrok..."
                        sleep 10

                        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | cut -d '"' -f 4 | head -n 1)

                        if [ -n "$NGROK_URL" ]; then
                            echo "🌐 Application accessible sur: $NGROK_URL"
                            echo "✅ Health check: $NGROK_URL/health"
                            echo "👋 Test endpoint: $NGROK_URL/hello/Jenkins"
                            echo "$NGROK_URL" > ngrok_url.txt
                        else
                            echo "❌ Erreur: Impossible de récupérer l'URL ngrok"
                            cat ngrok.log
                            exit 1
                        fi
                    '''
                }
            }
        }
    }

    post {
        always {
            echo '🧹 Nettoyage final...'
            script {
                archiveArtifacts artifacts: '*.log', allowEmptyArchive: true
                cleanWs()
            }
        }

        success {
            echo '✅ Pipeline exécuté avec succès!'
            script {
                def ngrokUrl = ""
                try {
                    ngrokUrl = readFile('ngrok_url.txt').trim()
                } catch (Exception e) {
                    ngrokUrl = "URL non disponible"
                }

                emailext (
                    subject: "✅ Déploiement réussi - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>🎉 Déploiement réussi!</h2>
                        <p><strong>Projet:</strong> ${env.JOB_NAME}</p>
                        <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                        <p><strong>Commit:</strong> ${env.GIT_COMMIT_MSG}</p>
                        <p><strong>URL publique:</strong> <a href="${ngrokUrl}">${ngrokUrl}</a></p>
                        <p><strong>Endpoints disponibles:</strong></p>
                        <ul>
                            <li><a href="${ngrokUrl}/">Accueil</a></li>
                            <li><a href="${ngrokUrl}/health">Health Check</a></li>
                            <li><a href="${ngrokUrl}/hello/World">Hello World</a></li>
                        </ul>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }

        failure {
            echo '❌ Échec du pipeline'
            emailext (
                subject: "❌ Échec du déploiement - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                body: """
                    <h2>❌ Échec du déploiement</h2>
                    <p><strong>Projet:</strong> ${env.JOB_NAME}</p>
                    <p><strong>Build:</strong> #${env.BUILD_NUMBER}</p>
                    <p><strong>Commit:</strong> ${env.GIT_COMMIT_MSG}</p>
                    <p><strong>Console:</strong> <a href="${env.BUILD_URL}console">Voir les logs</a></p>
                """,
                to: '${DEFAULT_RECIPIENTS}',
                mimeType: 'text/html'
            )
        }

        unstable {
            echo '⚠️ Build instable'
        }
    }
}
