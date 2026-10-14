package com.authenticator.repository;

import com.authenticator.domain.TrustedDevice;
import com.authenticator.domain.TrustedDeviceStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TrustedDeviceRepository extends JpaRepository<TrustedDevice, UUID> {

    List<TrustedDevice> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<TrustedDevice> findByUserIdAndDeviceHash(UUID userId, String deviceHash);

    long countByUserIdAndStatusNot(UUID userId, TrustedDeviceStatus status);

    long countByUserIdAndStatus(UUID userId, TrustedDeviceStatus status);

    List<TrustedDevice> findByUserIdAndStatusIn(UUID userId, Collection<TrustedDeviceStatus> statuses);
}
