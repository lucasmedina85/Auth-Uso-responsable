package com.authenticator.repository;

import com.authenticator.domain.OAuthAuthorizationCode;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface OAuthAuthorizationCodeRepository extends JpaRepository<OAuthAuthorizationCode, UUID> {
    Optional<OAuthAuthorizationCode> findByCodeHash(String codeHash);
    void deleteByExpiresAtBefore(LocalDateTime threshold);
}
