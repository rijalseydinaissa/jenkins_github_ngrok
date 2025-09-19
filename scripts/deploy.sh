#!/bin/bash

echo "🚀 Démarrage du script de déploiement..."

# Variables
JAR_FILE="target/my-java-app-1.0-SNAPSHOT.jar"
APP_PORT=8080
LOG_FILE="app.log"

# Vérifier que le JAR existe
if [ ! -f "$JAR_FILE" ]; then
    echo "❌ Erreur: Le fichier JAR $JAR_FILE n'existe pas"
    exit 1
fi

# Lancer l'application en arrière-plan
echo "🏃‍♂️ Lancement de l'application Java..."
nohup java -jar "$JAR_FILE" --server.port=$APP_PORT > "$LOG_FILE" 2>&1 &
APP_PID=$!

# Sauvegarder le PID
echo $APP_PID > app.pid
echo "📋 Application lancée avec PID: $APP_PID"

# Attendre que l'application démarre
echo "⏳ Attente du démarrage de l'application..."
for i in {1..30}; do
    if curl -s http://localhost:$APP_PORT/health > /dev/null; then
        echo "✅ Application démarrée avec succès !"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Timeout: L'application n'a pas démarré dans les temps"
        exit 1
    fi
    sleep 2
done

echo "🎉 Déploiement terminé !"