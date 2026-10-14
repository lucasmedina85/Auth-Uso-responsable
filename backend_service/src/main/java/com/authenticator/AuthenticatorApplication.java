package com.authenticator;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class AuthenticatorApplication {
    public static void main(String[] args) {
        SpringApplication.run(AuthenticatorApplication.class, args);
    }
}
