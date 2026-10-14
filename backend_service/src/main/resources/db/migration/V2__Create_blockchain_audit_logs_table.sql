CREATE TABLE blockchain_audit_logs (
    id UUID PRIMARY KEY,
    session_id VARCHAR(255) NOT NULL,
    session_hash VARCHAR(64) NOT NULL,
    decision VARCHAR(50) NOT NULL,
    score INT NOT NULL,
    risk_config_version VARCHAR(50) NOT NULL,
    breakdown_hash VARCHAR(64) NOT NULL,
    breakdown_details_json TEXT NOT NULL,
    status VARCHAR(50) NOT NULL,
    transaction_hash VARCHAR(100),
    retry_count INT DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMP NOT NULL,
    confirmed_at TIMESTAMP
);

CREATE INDEX idx_blockchain_audit_status ON blockchain_audit_logs(status);
CREATE INDEX idx_blockchain_audit_session_hash ON blockchain_audit_logs(session_hash);
CREATE UNIQUE INDEX uq_blockchain_session_decision ON blockchain_audit_logs(session_hash, decision);
