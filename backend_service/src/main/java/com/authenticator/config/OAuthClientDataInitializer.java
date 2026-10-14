package com.authenticator.config;

import com.authenticator.domain.OAuthClient;
import com.authenticator.repository.OAuthClientRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Set;

@Component
@Profile({"dev", "test"})
public class OAuthClientDataInitializer implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(OAuthClientDataInitializer.class);

    private final OAuthClientRepository clientRepository;
    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder();

    public OAuthClientDataInitializer(OAuthClientRepository clientRepository) {
        this.clientRepository = clientRepository;
    }

    @Override
    public void run(String... args) {
        if (!clientRepository.existsById("sandbox-client")) {
            OAuthClient sandbox = new OAuthClient();
            sandbox.setClientId("sandbox-client");
            sandbox.setClientSecretHash(passwordEncoder.encode("sandbox-secret-12345"));
            sandbox.setName("Plataforma de Juegos Sandbox");
            sandbox.setAllowedScopes("openid,age_verification");
            sandbox.setRedirectUris(Set.of(
                    "https://sandbox.tercero.com/callback",
                    "sipdemo://callback",
                    "http://127.0.0.1:8080/oauth/sandbox/callback",
                    "http://localhost:8080/oauth/sandbox/callback"
            ));
            clientRepository.save(sandbox);
            log.info("Cliente OAuth 'sandbox-client' sembrado exitosamente para entorno de desarrollo/test.");
        }
    }
}
