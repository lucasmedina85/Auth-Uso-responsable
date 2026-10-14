package com.authenticator.repository;

import com.authenticator.domain.OAuthClient;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface OAuthClientRepository extends JpaRepository<OAuthClient, String> {
    Optional<OAuthClient> findByClientIdAndStatus(String clientId, String status);
}
