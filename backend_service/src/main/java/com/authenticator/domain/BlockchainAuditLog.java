package com.authenticator.domain;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

/**
 * Entidad de persistencia off-chain para logs de auditoría en Blockchain (CU-0030 / CU-0047).
 * Almacena el desglose probatorio en la base de datos junto al hash certificado on-chain.
 */
@Entity
@Table(name = "blockchain_audit_logs")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BlockchainAuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "session_id", nullable = false)
    private String sessionId;

    @Column(name = "session_hash", nullable = false, length = 64)
    private String sessionHash;

    @Column(name = "decision", nullable = false, length = 50)
    private String decision;

    @Column(name = "score", nullable = false)
    private int score;

    @Column(name = "risk_config_version", nullable = false, length = 50)
    private String riskConfigVersion;

    @Column(name = "breakdown_hash", nullable = false, length = 64)
    private String breakdownHash;

    @Column(name = "breakdown_details_json", nullable = false, columnDefinition = "TEXT")
    private String breakdownDetailsJson;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 50)
    private BlockchainTxStatus status;

    @Column(name = "transaction_hash", length = 100)
    private String transactionHash;

    @Builder.Default
    @Column(name = "retry_count")
    private int retryCount = 0;

    @Column(name = "error_message", columnDefinition = "TEXT")
    private String errorMessage;

    @Column(name = "masked_ip", length = 50)
    private String maskedIp;

    @Column(name = "dni_hash", length = 64)
    private String dniHash;

    @Column(name = "dni_search_hash", length = 64)
    private String dniSearchHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "confirmed_at")
    private LocalDateTime confirmedAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
        if (status == null) {
            status = BlockchainTxStatus.PENDING;
        }
    }
}
