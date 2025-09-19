# ----------------------
# Étape 1 : Build
# ----------------------
FROM maven:3.9.0-eclipse-temurin-21-jdk AS build

WORKDIR /app

# Copier pom.xml d'abord pour profiter du cache Docker
COPY pom.xml .

# Copier le code source
COPY src ./src

# Build du projet sans tests
RUN mvn clean package -DskipTests

# ----------------------
# Étape 2 : Runtime
# ----------------------
FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app

# Copier le JAR construit depuis l'étape précédente
COPY --from=build /app/target/mon-app-java-1.0.0.jar app.jar

# Exposer le port de l'application
EXPOSE 8080

# Variables d'environnement
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SERVER_PORT=8080

# Lancer l'application
ENTRYPOINT ["sh", "-c", "java --enable-preview $JAVA_OPTS -jar app.jar"]
