package com.authenticator.repository;

import com.authenticator.domain.LinkedApplication;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface LinkedApplicationRepository extends JpaRepository<LinkedApplication, UUID> {
    Optional<LinkedApplication> findByUserIdAndClientId(UUID userId, String clientId);
    List<LinkedApplication> findByUserIdOrderByLastUsedAtDesc(UUID userId);
}
