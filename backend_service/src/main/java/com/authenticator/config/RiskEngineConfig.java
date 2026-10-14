package com.authenticator.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;
import java.time.ZoneId;

@Configuration
public class RiskEngineConfig {

    @Bean
    public Clock riskClock(@Value("${app.risk.timezone:America/Argentina/Buenos_Aires}") String timezone) {
        return Clock.system(ZoneId.of(timezone));
    }
}
