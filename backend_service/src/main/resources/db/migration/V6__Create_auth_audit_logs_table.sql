-- V6: Create auth_audit_logs table (Auditoría de eventos de autenticación)

CREATE TABLE auth_audit_logs (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    email_hmac VARCHAR(64) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    result VARCHAR(50) NOT NULL,
    masked_ip VARCHAR(50),
    device_hash VARCHAR(64),
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_auth_audit_logs_user_id ON auth_audit_logs(user_id);
CREATE INDEX idx_auth_audit_logs_created_at ON auth_audit_logs(created_at);
CREATE INDEX idx_auth_audit_logs_email_hmac ON auth_audit_logs(email_hmac);
