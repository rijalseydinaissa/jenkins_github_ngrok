#!/bin/bash

echo "🌐 Démarrage de ngrok..."

# Configuration
APP_PORT=8080
NGROK_CONFIG_DIR="$HOME/.ngrok2"
NGROK_LOG="ngrok.log"

# Créer le répertoire de configuration si nécessaire
mkdir -p "$NGROK_CONFIG_DIR"

# Lancer ngrok en arrière-plan
echo "🚀 Lancement de ngrok pour le port $APP_PORT..."
nohup ngrok http $APP_PORT --log=stdout > "$NGROK_LOG" 2>&1 &
NGROK_PID=$!

# Sauvegarder le PID de ngrok
echo $NGROK_PID > ngrok.pid
echo "📋 ngrok lancé avec PID: $NGROK_PID"

# Attendre que ngrok se connecte
echo "⏳ Attente de la connexion ngrok..."
sleep 10

# Récupérer et afficher l'URL
if curl -s http://localhost:4040/api/tunnels > /dev/null; then
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for tunnel in data['tunnels']:
        if tunnel['proto'] == 'https':
            print(tunnel['public_url'])
            break
except:
    print('URL non disponible')
" 2>/dev/null)

    if [ "$NGROK_URL" != "URL non disponible" ] && [ -n "$NGROK_URL" ]; then
        echo "🌍 Application accessible publiquement sur: $NGROK_URL"
        echo "🏠 Application accessible localement sur: http://localhost:$APP_PORT"

        # Sauvegarder l'URL pour référence
        echo "$NGROK_URL" > ngrok_url.txt
    else
        echo "⚠️  Impossible de récupérer l'URL ngrok"
    fi
else
    echo "❌ ngrok API non accessible"
fi

echo "✅ Configuration ngrok terminée !"