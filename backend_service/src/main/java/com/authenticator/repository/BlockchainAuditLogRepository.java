package com.authenticator.repository;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.BlockchainTxStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface BlockchainAuditLogRepository extends JpaRepository<BlockchainAuditLog, UUID> {

    List<BlockchainAuditLog> findByStatus(BlockchainTxStatus status);

    List<BlockchainAuditLog> findTop20ByStatusOrderByCreatedAtAsc(BlockchainTxStatus status);

    Optional<BlockchainAuditLog> findBySessionHashAndDecision(String sessionHash, String decision);

    List<BlockchainAuditLog> findBySessionHash(String sessionHash);

    List<BlockchainAuditLog> findByDniSearchHashOrderByCreatedAtDesc(String dniSearchHash);

    Optional<BlockchainAuditLog> findFirstByDniHashOrderByCreatedAtDesc(String dniHash);

    List<BlockchainAuditLog> findByDniHashOrderByCreatedAtDesc(String dniHash);

    long countByStatus(BlockchainTxStatus status);
}
