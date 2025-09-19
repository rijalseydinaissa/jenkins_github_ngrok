FROM openjdk:21-jdk-slim

LABEL maintainer="votre-email@example.com"
LABEL description="Application Java 21 avec Spring Boot"

WORKDIR /app

# Copier les fichiers Maven
COPY pom.xml .
COPY src ./src

# Installer Maven
RUN apt-get update && apt-get install -y maven

# Build de l'application
RUN mvn clean package -DskipTests

# Exposer le port
EXPOSE 8080

# Variables d'environnement
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SERVER_PORT=8080

# Commande de démarrage
CMD ["java", "--enable-preview", "-jar", "target/mon-app-java-1.0.0.jar"]