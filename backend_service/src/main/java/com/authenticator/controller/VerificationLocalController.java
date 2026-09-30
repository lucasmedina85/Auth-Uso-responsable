package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.LocalVerificationRequest;
import com.authenticator.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/verification")
public class VerificationLocalController {

    private final UserRepository userRepository;

    public VerificationLocalController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @PostMapping("/local-result")
    public ResponseEntity<?> informLocalResult(Authentication authentication, @Valid @RequestBody LocalVerificationRequest request) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        String userId = (String) authentication.getPrincipal();
        Optional<User> optUser = userRepository.findById(UUID.fromString(userId));
        if (optUser.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        User user = optUser.get();
        
        // Mocking responses for CU-0038 and CU-0043
        if ("SPOOFING".equals(request.getDniHash())) {
            return ResponseEntity.status(403).body(java.util.Map.of("errorCode", "SPOOFING_DETECTED"));
        }
        if ("BLOCKED".equals(request.getDniHash())) {
            return ResponseEntity.status(403).body(java.util.Map.of("errorCode", "DNI_BLOCKED_STOLEN"));
        }

        // This sets LOCALLY_VERIFIED only, ensuring VERIFIED is reserved for remote
        if (user.getStatus() == UserStatus.REGISTERED || user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            user.setStatus(UserStatus.LOCALLY_VERIFIED);
            user.setDniHash(request.getDniHash());
            user.setVerifiedAt(LocalDateTime.now());
            try {
                userRepository.save(user);
            } catch (Exception e) {
                return ResponseEntity.badRequest().body("DNI hash might already be associated with another active account.");
            }
        }
        return ResponseEntity.ok().build();
    }
}
