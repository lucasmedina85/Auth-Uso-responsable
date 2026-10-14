-- V5: Create trusted_devices table (CU-0035 / CU-0040)

CREATE TABLE trusted_devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_hash VARCHAR(64) NOT NULL,
    device_name VARCHAR(100),
    manufacturer VARCHAR(100),
    os_version VARCHAR(50),
    device_type VARCHAR(20) NOT NULL DEFAULT 'MOBILE',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    first_seen_at TIMESTAMP NOT NULL,
    last_seen_at TIMESTAMP NOT NULL,
    trust_evaluated_at TIMESTAMP,
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT uq_trusted_device_user_hash UNIQUE (user_id, device_hash)
);

CREATE INDEX idx_trusted_devices_user ON trusted_devices(user_id);
CREATE INDEX idx_trusted_devices_hash ON trusted_devices(device_hash);
