# Étape 1 : Build pour construire l'image
FROM maven:3.9.0-eclipse-temurin-21 AS build

WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Étape 2 : Runtime
FROM eclipse-temurin:21-jdk-jammy

WORKDIR /app
COPY --from=build /app/target/mon-app-java-1.0.0.jar app.jar

EXPOSE 8080

ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SERVER_PORT=8080

ENTRYPOINT ["sh", "-c", "java --enable-preview $JAVA_OPTS -jar app.jar"]
