package com.authenticator.config;

import com.authenticator.AuthenticatorApplication;
import org.junit.jupiter.api.Test;
import org.springframework.boot.builder.SpringApplicationBuilder;

import static org.junit.jupiter.api.Assertions.assertThrows;

public class ProdStartupValidationTest {

    @Test
    public void contextLoads_InProdProfileWithoutSessionHashSecret_FailsToStart() {
        assertThrows(Exception.class, () -> {
            new SpringApplicationBuilder(AuthenticatorApplication.class)
                    .profiles("prod")
                    .run();
        });
    }
}
