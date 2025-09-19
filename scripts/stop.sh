#!/bin/bash

echo "🛑 Arrêt de l'application..."

# Arrêter l'application Java
if [ -f app.pid ]; then
    APP_PID=$(cat app.pid)
    kill $APP_PID 2>/dev/null && echo "✅ Application arrêtée (PID: $APP_PID)"
    rm app.pid
fi

# Arrêter ngrok
if [ -f ngrok.pid ]; then
    NGROK_PID=$(cat ngrok.pid)
    kill $NGROK_PID 2>/dev/null && echo "✅ ngrok arrêté (PID: $NGROK_PID)"
    rm ngrok.pid
fi

# Nettoyage des processus restants
pkill -f "java.*my-java-app" 2>/dev/null
pkill ngrok 2>/dev/null

echo "🧹 Arrêt terminé !"