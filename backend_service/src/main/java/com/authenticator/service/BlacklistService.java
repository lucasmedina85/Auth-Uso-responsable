package com.authenticator.service;

import com.authenticator.domain.BlacklistedDni;
import com.authenticator.repository.BlacklistedDniRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Optional;

@Service
public class BlacklistService {

    private final BlacklistedDniRepository blacklistedDniRepository;

    public BlacklistService(BlacklistedDniRepository blacklistedDniRepository) {
        this.blacklistedDniRepository = blacklistedDniRepository;
    }

    @Transactional(readOnly = true)
    public boolean isDniBlacklisted(String dniHash) {
        if (dniHash == null || dniHash.isBlank()) {
            return false;
        }
        return blacklistedDniRepository.existsByDniHash(dniHash);
    }

    @Transactional(readOnly = true)
    public Optional<BlacklistedDni> getBlacklistedDni(String dniHash) {
        if (dniHash == null || dniHash.isBlank()) {
            return Optional.empty();
        }
        return blacklistedDniRepository.findByDniHash(dniHash);
    }

    @Transactional
    public BlacklistedDni blacklistDni(String dniHash, String reason) {
        BlacklistedDni entry = BlacklistedDni.builder()
                .dniHash(dniHash)
                .reason(reason)
                .createdAt(LocalDateTime.now())
                .build();
        return blacklistedDniRepository.save(entry);
    }
}
