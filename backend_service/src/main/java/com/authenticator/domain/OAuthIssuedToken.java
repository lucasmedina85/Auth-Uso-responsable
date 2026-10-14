package com.authenticator.domain;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "oauth_issued_tokens")
@Data
@NoArgsConstructor
public class OAuthIssuedToken {
    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "token_id_hash", nullable = false, unique = true, length = 64)
    private String tokenIdHash;

    @Column(name = "jti", length = 100)
    private String jti;

    @Column(name = "code_hash", nullable = false, length = 64)
    private String codeHash;

    @Column(name = "client_id", nullable = false, length = 100)
    private String clientId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Column(nullable = false, length = 50)
    private String status = "ACTIVE";

    @Column(name = "revoked_at")
    private LocalDateTime revokedAt;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
    }
}
