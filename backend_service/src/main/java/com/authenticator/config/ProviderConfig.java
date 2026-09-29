package com.authenticator.config;

import com.authenticator.service.IdentityVerificationProvider;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationContext;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class ProviderConfig {

    @Value("${app.identity-provider:mock}")
    private String providerType;

    @Bean
    public IdentityVerificationProvider identityVerificationProvider(ApplicationContext context) {
        switch (providerType.toLowerCase()) {
            case "didit":
                return context.getBean("diditProvider", IdentityVerificationProvider.class);
            case "official":
                throw new UnsupportedOperationException("Official provider not implemented yet");
            case "mock":
            default:
                return context.getBean("mockProvider", IdentityVerificationProvider.class);
        }
    }
}
