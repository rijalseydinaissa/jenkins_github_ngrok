#!/bin/bash

echo "📊 Statut de l'application"
echo "=========================="

# Statut de l'application
if curl -s http://localhost:8080/health > /dev/null; then
    echo "✅ Application: EN COURS"
    echo "🏠 URL locale: http://localhost:8080"
else
    echo "❌ Application: ARRÊTÉE"
fi

# Statut de ngrok
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
    print('Non disponible')
" 2>/dev/null)
    echo "✅ ngrok: EN COURS"
    echo "🌍 URL publique: $NGROK_URL"
else
    echo "❌ ngrok: ARRÊTÉ"
fi