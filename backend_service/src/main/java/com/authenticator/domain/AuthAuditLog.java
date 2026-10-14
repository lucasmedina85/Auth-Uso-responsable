package com.authenticator.domain;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "auth_audit_logs")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuthAuditLog {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "email_hmac", nullable = false, length = 64)
    private String emailHmac;

    @Column(name = "event_type", nullable = false, length = 50)
    private String eventType;

    @Column(name = "result", nullable = false, length = 50)
    private String result;

    @Column(name = "masked_ip", length = 50)
    private String maskedIp;

    @Column(name = "device_hash", length = 64)
    private String deviceHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        if (createdAt == null) {
            createdAt = LocalDateTime.now();
        }
    }
}
