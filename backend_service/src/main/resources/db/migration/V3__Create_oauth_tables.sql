CREATE TABLE oauth_clients (
    client_id VARCHAR(100) PRIMARY KEY,
    client_secret_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    allowed_scopes VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL
);

CREATE TABLE oauth_client_redirect_uris (
    client_id VARCHAR(100) NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
    redirect_uri VARCHAR(500) NOT NULL,
    PRIMARY KEY (client_id, redirect_uri)
);

CREATE TABLE oauth_authorization_codes (
    id UUID PRIMARY KEY,
    code_hash VARCHAR(64) NOT NULL UNIQUE,
    client_id VARCHAR(100) NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    redirect_uri VARCHAR(500) NOT NULL,
    code_challenge VARCHAR(128) NOT NULL,
    code_challenge_method VARCHAR(10) NOT NULL DEFAULT 'S256',
    nonce VARCHAR(255),
    scope VARCHAR(255),
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN NOT NULL DEFAULT FALSE,
    used_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_oauth_auth_codes_hash ON oauth_authorization_codes(code_hash);
CREATE INDEX idx_oauth_auth_codes_expires ON oauth_authorization_codes(expires_at);

CREATE TABLE oauth_issued_tokens (
    id UUID PRIMARY KEY,
    token_id_hash VARCHAR(64) NOT NULL UNIQUE,
    code_hash VARCHAR(64) NOT NULL,
    client_id VARCHAR(100) NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    revoked_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_oauth_tokens_id_hash ON oauth_issued_tokens(token_id_hash);
CREATE INDEX idx_oauth_tokens_code_hash ON oauth_issued_tokens(code_hash);
CREATE INDEX idx_oauth_tokens_expires ON oauth_issued_tokens(expires_at);

CREATE TABLE linked_applications (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_id VARCHAR(100) NOT NULL REFERENCES oauth_clients(client_id) ON DELETE CASCADE,
    linked_at TIMESTAMP NOT NULL,
    last_used_at TIMESTAMP NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'ACTIVE',
    scopes VARCHAR(255),
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    CONSTRAINT uq_linked_app_user_client UNIQUE (user_id, client_id)
);

CREATE INDEX idx_linked_apps_user ON linked_applications(user_id);

CREATE TABLE oauth_audit_logs (
    id UUID PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    client_id VARCHAR(100) NOT NULL,
    user_id_hash VARCHAR(64) NOT NULL,
    details TEXT,
    created_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_oauth_audit_client ON oauth_audit_logs(client_id);
CREATE INDEX idx_oauth_audit_created ON oauth_audit_logs(created_at);
