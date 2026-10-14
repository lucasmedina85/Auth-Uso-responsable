package com.authenticator.repository;

import com.authenticator.domain.AuthAuditLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface AuthAuditLogRepository extends JpaRepository<AuthAuditLog, UUID> {

    List<AuthAuditLog> findByUserIdOrderByCreatedAtDesc(UUID userId);

    long countByEmailHmacAndCreatedAtAfter(String emailHmac, LocalDateTime after);

    long countByMaskedIpAndCreatedAtAfter(String maskedIp, LocalDateTime after);

    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("DELETE FROM AuthAuditLog a WHERE a.createdAt < :cutoff")
    int deleteOlderThan(@Param("cutoff") LocalDateTime cutoff);
}
