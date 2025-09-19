#!/bin/bash

echo "🚀 Script de déploiement avancé"

# Variables
APP_NAME="mon-app-java"
PORT=8080
CONTAINER_NAME="${APP_NAME}-container"
IMAGE_NAME="${APP_NAME}:latest"

# Fonctions
log_info() {
    echo "ℹ️  [INFO] $1"
}

log_error() {
    echo "❌ [ERROR] $1"
    exit 1
}

log_success() {
    echo "✅ [SUCCESS] $1"
}

# Vérifications préalables
check_requirements() {
    log_info "Vérification des prérequis..."

    command -v docker >/dev/null 2>&1 || log_error "Docker n'est pas installé"
    command -v java >/dev/null 2>&1 || log_error "Java n'est pas installé"
    command -v mvn >/dev/null 2>&1 || log_error "Maven n'est pas installé"

    # Vérifier Java 21
    java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
    if [ "$java_version" != "21" ]; then
        log_error "Java 21 requis, trouvé: Java $java_version"
    fi

    log_success "Tous les prérequis sont satisfaits"
}

# Nettoyage
cleanup() {
    log_info "Nettoyage des ressources existantes..."

    # Arrêter et supprimer le conteneur existant
    if docker ps -a --format 'table {{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_info "Conteneur existant supprimé"
    fi

    # Supprimer l'image existante
    if docker images --format 'table {{.Repository}}:{{.Tag}}' | grep -q "^${IMAGE_NAME}$"; then
        docker rmi "$IMAGE_NAME" 2>/dev/null || true
        log_info "Image existante supprimée"
    fi
}

# Build
build_app() {
    log_info "Construction de l'application..."

    mvn clean package -DskipTests -q || log_error "Échec du build Maven"

    if [ ! -f "target/${APP_NAME}-1.0.0.jar" ]; then
        log_error "JAR non trouvé après le build"
    fi

    log_success "Build Maven réussi"
}

# Docker build
build_docker() {
    log_info "Construction de l'image Docker..."

    docker build -t "$IMAGE_NAME" . || log_error "Échec du build Docker"

    log_success "Image Docker construite"
}

# Deploy
deploy() {
    log_info "Déploiement de l'application..."

    docker run -d \
        --name "$CONTAINER_NAME" \
        -p "$PORT:$PORT" \
        -e SPRING_PROFILES_ACTIVE=prod \
        --restart unless-stopped \
        "$IMAGE_NAME" || log_error "Échec du déploiement"

    log_success "Application déployée"
}

# Health check
health_check() {
    log_info "Vérification de la santé de l'application..."

    max_attempts=30
    attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f "http://localhost:$PORT/health" >/dev/null 2>&1; then
            log_success "Application opérationnelle!"
            return 0
        fi

        log_info "Tentative $attempt/$max_attempts - En attente..."
        sleep 5
        attempt=$((attempt + 1))
    done

    log_error "L'application n'a pas démarré dans les temps"
}

# Fonction principale
main() {
    echo "🚀 Début du déploiement de $APP_NAME"
    echo "================================================"

    check_requirements
    cleanup
    build_app
    build_docker
    deploy
    health_check

    echo "================================================"
    log_success "Déploiement terminé avec succès!"
    echo "🌐 Application accessible sur: http://localhost:$PORT"
    echo "💊 Health check: http://localhost:$PORT/health"
    echo "👋 Test: http://localhost:$PORT/hello/World"
}

# Exécution
main "$@"