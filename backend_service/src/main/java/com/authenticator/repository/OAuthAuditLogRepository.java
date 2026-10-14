package com.authenticator.repository;

import com.authenticator.domain.OAuthAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface OAuthAuditLogRepository extends JpaRepository<OAuthAuditLog, UUID> {
    List<OAuthAuditLog> findByClientIdOrderByCreatedAtDesc(String clientId);
    List<OAuthAuditLog> findByUserIdHashOrderByCreatedAtDesc(String userIdHash);
}
