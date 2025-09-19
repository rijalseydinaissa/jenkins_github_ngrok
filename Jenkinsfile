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
                checkout scm
                script {
                    env.GIT_COMMIT_MSG = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()
                    echo "✅ Commit message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('🔍 Analyse Environnement') {
            steps {
                script {
                    def javaVersion = sh(script: 'java -version 2>&1 | head -n 1', returnStdout: true).trim()
                    if (!javaVersion.contains('21')) {
                        error("❌ Java 21 requis, trouvé: ${javaVersion}")
                    } else {
                        echo "✅ Java version OK: ${javaVersion}"
                    }
                }
                sh '''
#!/bin/bash
echo "Java Version:"
java -version
echo "JAVA_HOME: $JAVA_HOME"
echo "Maven Version:"
mvn -version
echo "Git Version:"
git --version
'''
            }
        }

        stage('🧹 Clean') {
            steps { sh 'mvn clean' }
        }

        stage('🔧 Compile') {
            steps { sh 'mvn compile -Dmaven.compiler.source=21 -Dmaven.compiler.target=21' }
        }

        stage('📦 Package') {
            steps {
                sh 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('🐳 Docker Build') {
            steps {
                script {
                    sh '''
#!/bin/bash
docker stop ${CONTAINER_NAME} || true
docker rm ${CONTAINER_NAME} || true
docker rmi ${DOCKER_IMAGE} || true
docker build -t ${DOCKER_IMAGE} ${env.WORKSPACE}
'''
                }
            }
        }

        stage('🚀 Deploy Local') {
            steps {
                script {
                    sh """
#!/bin/bash
docker run -d \\
    --name ${CONTAINER_NAME} \\
    -p ${APP_PORT}:${APP_PORT} \\
    -e SPRING_PROFILES_ACTIVE=prod \\
    ${DOCKER_IMAGE}
"""
                    sh '''
#!/bin/bash
timeout=60
while [ $timeout -gt 0 ]; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Application démarrée!"
        break
    fi
    echo "⏳ En attente... ($timeout s restants)"
    sleep 5
    timeout=$((timeout-5))
done

if [ $timeout -le 0 ]; then
    echo "❌ Timeout: application non démarrée"
    exit 1
fi
'''
                }
            }
        }

        stage('🌐 Expose via ngrok') {
            steps {
                script {
                    sh '''
#!/bin/bash
pkill ngrok || true
ngrok config add-authtoken $NGROK_TOKEN
nohup ngrok http ${APP_PORT} --log=stdout > ngrok.log 2>&1 &
sleep 10

NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | cut -d '"' -f 4 | head -n 1)
if [ -n "$NGROK_URL" ]; then
    echo "🌐 Accessible sur: $NGROK_URL"
    echo "$NGROK_URL" > ngrok_url.txt
else
    echo "❌ Impossible de récupérer l'URL ngrok"
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
            archiveArtifacts artifacts: '*.log', allowEmptyArchive: true
            cleanWs()
        }
        success {
            script {
                def ngrokUrl = ""
                try { ngrokUrl = readFile('ngrok_url.txt').trim() } catch (Exception e) { ngrokUrl = "URL non disponible" }
                emailext(
                    subject: "✅ Déploiement réussi - ${env.JOB_NAME} #${env.BUILD_NUMBER}",
                    body: """
                        <h2>🎉 Déploiement réussi!</h2>
                        <p>Build: #${env.BUILD_NUMBER}</p>
                        <p>Commit: ${env.GIT_COMMIT_MSG}</p>
                        <p>URL publique: <a href="${ngrokUrl}">${ngrokUrl}</a></p>
                    """,
                    to: '${DEFAULT_RECIPIENTS}',
                    mimeType: 'text/html'
                )
            }
        }
        failure {
            echo '❌ Échec du pipeline'
        }
    }
}
