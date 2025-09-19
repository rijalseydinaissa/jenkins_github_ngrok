# ----------------------
# Étape 1 : Build
# ----------------------
FROM maven:3.9.4-eclipse-temurin-17 AS build

WORKDIR /app

# Copier le pom.xml pour télécharger les dépendances
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copier le code source et compiler
COPY src ./src
RUN mvn clean package -DskipTests

# ----------------------
# Étape 2 : Runtime
# ----------------------
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Créer un utilisateur non-root pour la sécurité
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copier le JAR depuis l'étape de build
COPY --from=build /app/target/my-java-app-1.0-SNAPSHOT.jar app.jar

# Changer la propriété du fichier
RUN chown appuser:appuser app.jar

# Exposer le port
EXPOSE 8080

# Variables d'environnement
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC"
ENV SERVER_PORT=8080
ENV SPRING_PROFILES_ACTIVE=prod

# Basculer vers l'utilisateur non-root
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Point d'entrée
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]