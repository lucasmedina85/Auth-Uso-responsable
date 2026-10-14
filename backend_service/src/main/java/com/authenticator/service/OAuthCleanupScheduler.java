package com.authenticator.service;

import com.authenticator.repository.OAuthAuthorizationCodeRepository;
import com.authenticator.repository.OAuthIssuedTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Component
public class OAuthCleanupScheduler {

    private static final Logger log = LoggerFactory.getLogger(OAuthCleanupScheduler.class);

    private final OAuthAuthorizationCodeRepository codeRepository;
    private final OAuthIssuedTokenRepository tokenRepository;

    public OAuthCleanupScheduler(OAuthAuthorizationCodeRepository codeRepository,
                                 OAuthIssuedTokenRepository tokenRepository) {
        this.codeRepository = codeRepository;
        this.tokenRepository = tokenRepository;
    }

    @Scheduled(fixedDelayString = "${app.oauth.cleanup-interval-ms:300000}")
    @Transactional
    public void purgeExpiredEntries() {
        LocalDateTime now = LocalDateTime.now();
        try {
            codeRepository.deleteByExpiresAtBefore(now);
            tokenRepository.deleteByExpiresAtBefore(now);
            log.debug("Purga programada de códigos y tokens OAuth expirados ejecutada a las {}", now);
        } catch (Exception e) {
            log.error("Error durante la purga de códigos y tokens OAuth expirados: {}", e.getMessage(), e);
        }
    }
}
