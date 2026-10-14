package com.authenticator.repository;

import com.authenticator.domain.OAuthIssuedToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OAuthIssuedTokenRepository extends JpaRepository<OAuthIssuedToken, UUID> {
    Optional<OAuthIssuedToken> findByTokenIdHash(String tokenIdHash);
    Optional<OAuthIssuedToken> findByJti(String jti);
    List<OAuthIssuedToken> findByCodeHash(String codeHash);
    List<OAuthIssuedToken> findByUserIdAndClientIdOrderByCreatedAtDesc(UUID userId, String clientId);
    List<OAuthIssuedToken> findByUserIdOrderByCreatedAtDesc(UUID userId);
    void deleteByExpiresAtBefore(LocalDateTime threshold);
}
