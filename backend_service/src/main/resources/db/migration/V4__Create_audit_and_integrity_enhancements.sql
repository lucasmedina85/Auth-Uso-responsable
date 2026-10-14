-- V4: Audit, Integrity, and Role Enhancements (CU-0029, CU-0047, CU-0043, CU-0037)

-- 1. Rol persistido en la base de datos para usuarios
ALTER TABLE users ADD COLUMN role VARCHAR(50) NOT NULL DEFAULT 'USER';

-- 2. Registro de transacción off-chain enriquecido (timestamp, IP enmascarada, hash de DNI e identificador HMAC de búsqueda)
ALTER TABLE blockchain_audit_logs ADD COLUMN masked_ip VARCHAR(50);
ALTER TABLE blockchain_audit_logs ADD COLUMN dni_hash VARCHAR(64);
ALTER TABLE blockchain_audit_logs ADD COLUMN dni_search_hash VARCHAR(64);

CREATE INDEX idx_blockchain_logs_dni_search ON blockchain_audit_logs(dni_search_hash);

-- 3. JTI indexado para revocación activa en OAuth
ALTER TABLE oauth_issued_tokens ADD COLUMN jti VARCHAR(100);

CREATE INDEX idx_oauth_tokens_jti ON oauth_issued_tokens(jti);

-- 4. Soporte para webhooks de notificación en clientes OAuth
ALTER TABLE oauth_clients ADD COLUMN webhook_url VARCHAR(500);
ALTER TABLE oauth_clients ADD COLUMN webhook_secret VARCHAR(255);

-- 5. Tabla de DNIs en lista negra (CU-0043)
CREATE TABLE blacklisted_dnis (
    dni_hash VARCHAR(64) PRIMARY KEY,
    reason VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL
);
