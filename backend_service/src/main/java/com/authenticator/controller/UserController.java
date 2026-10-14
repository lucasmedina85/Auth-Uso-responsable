package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.SecurityScoreResponse;
import com.authenticator.dto.UserActivityPageResponse;
import com.authenticator.dto.UserResponse;
import com.authenticator.repository.UserRepository;
import com.authenticator.service.SecurityScoreService;
import com.authenticator.service.UserActivityService;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/users")
public class UserController {

    private final UserRepository userRepository;
    private final SecurityScoreService securityScoreService;
    private final UserActivityService userActivityService;
    private final com.authenticator.service.ReauthService reauthService;

    public UserController(UserRepository userRepository,
                          SecurityScoreService securityScoreService,
                          UserActivityService userActivityService,
                          com.authenticator.service.ReauthService reauthService) {
        this.userRepository = userRepository;
        this.securityScoreService = securityScoreService;
        this.userActivityService = userActivityService;
        this.reauthService = reauthService;
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getMe(Authentication authentication) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        String userId = (String) authentication.getPrincipal();
        Optional<User> optUser = userRepository.findById(UUID.fromString(userId));
        if (optUser.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        User user = optUser.get();
        UserResponse response = new UserResponse();
        response.setId(user.getId().toString());
        response.setEmail(user.getEmail());
        response.setStatus(user.getStatus());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/security-score")
    public ResponseEntity<SecurityScoreResponse> getSecurityScore(
            Authentication authentication,
            @RequestParam(value = "hasBiometrics", defaultValue = "false") boolean hasBiometrics,
            @RequestParam(value = "hasScreenLock", defaultValue = "false") boolean hasScreenLock) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.ok(securityScoreService.calculateScore(userId, hasBiometrics, hasScreenLock));
    }

    @GetMapping("/activity")
    public ResponseEntity<UserActivityPageResponse> getActivity(
            Authentication authentication,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "20") int size,
            @RequestParam(value = "type", required = false) String type,
            @RequestParam(value = "startDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(value = "endDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        try {
            UserActivityPageResponse response = userActivityService.getUserActivity(userId, page, size, type, startDate, endDate);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    @GetMapping("/activity/export")
    public ResponseEntity<?> exportActivity(
            Authentication authentication,
            @org.springframework.web.bind.annotation.RequestHeader(value = "X-Reauth-Token", required = false) String reauthToken,
            @RequestParam(value = "startDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(value = "endDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        UUID userId = UUID.fromString((String) authentication.getPrincipal());

        if (reauthToken == null || reauthToken.isBlank() || !reauthService.validateAndConsumeReauthToken(userId, reauthToken, "EXPORT")) {
            return ResponseEntity.status(403).body(Map.of("error", "Re-authentication required or invalid/expired token"));
        }

        try {
            Map<String, Object> exportData = userActivityService.exportUserActivity(userId, startDate, endDate);
            return ResponseEntity.ok(exportData);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
}
