package org.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.actuate.autoconfigure.wavefront.WavefrontProperties;

public class Main {
    public static void main(String[] args) {
        SpringApplication.run(WavefrontProperties.Application.class, args);
    }
}