package com.authenticator.repository;

import com.authenticator.domain.BlacklistedDni;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface BlacklistedDniRepository extends JpaRepository<BlacklistedDni, String> {
    Optional<BlacklistedDni> findByDniHash(String dniHash);
    boolean existsByDniHash(String dniHash);
}
