package org.example.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import java.time.LocalDateTime;
import java.util.Map;


@RestController
public class HelloController {

    @GetMapping("/")
    public Map<String, String> home() {
        return Map.of(
                "message", "Bienvenue sur mon API Java 21!",
                "timestamp", LocalDateTime.now().toString(),
                "version", "1.0.0",
                "java_version", System.getProperty("java.version")
        );
    }

    @GetMapping("/hello/{name}")
    public Map<String, String> hello(@PathVariable String name) {
        return Map.of(
                "timestamp", LocalDateTime.now().toString()
        );
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of(
                "status", "UP",
                "service", "Mon App Java 21"
        );
    }
}